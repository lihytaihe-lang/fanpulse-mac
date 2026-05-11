import Foundation
import Dispatch

// The command surface is intentionally tiny.
//
// The tool is designed around a very small set of operational tasks:
// - `boost`: temporarily force the fans to a maximum cooling state,
// - `restore`: hand control back if a previous run was interrupted,
// - `status`: show the current interpreted state in a human-friendly format,
// - `probe`: dump raw-ish key information for debugging/reverse-engineering.
//
// Keeping the command set narrow reduces accidental complexity when dealing with a private,
// hardware-facing interface such as AppleSMC.
private enum Command: String {
    case boost
    case restore
    case status
    case probe
}

// The snapshot file stores the machine state that existed before we forced the fans.
//
// Why this file exists at all:
// 1. We want to survive interruptions such as terminal closes or SIGINT.
// 2. We want a later `restore` command to work even after the original `boost` process exits.
// 3. We want the restore logic to be deterministic and not depend on guessing what "auto"
//    should look like on the current machine.
//
// `/var/tmp` is used because it outlives the process, but is still appropriate for temporary,
// machine-local state.
private enum AppPaths {
    static let stateFile = URL(fileURLWithPath: "/var/tmp/fanpulse-state.json")
}

// RestoreCoordinator makes restore behavior idempotent.
//
// Restore can be triggered from several different paths:
// - the normal "boost completed" path,
// - a signal handler,
// - an explicit later `restore` command.
//
// Without this guard we could end up writing target/mode values twice in overlapping ways,
// which is needlessly risky for hardware-facing code.
private final class RestoreCoordinator {
    private let smc: AppleSMC
    private var restored = false

    init(smc: AppleSMC) {
        self.smc = smc
    }

    func restore(from snapshot: FanSnapshot) {
        // Prevent double execution if multiple teardown paths fire.
        guard !restored else { return }
        restored = true

        do {
            // Restore target RPMs first. If a fan is still in manual mode for a brief moment,
            // it is better for the original target values to already be in place.
            for (index, rpm) in snapshot.targetRPMs.enumerated() {
                try smc.setFanTarget(fan: index, rpm: rpm)
            }

            // Then restore per-fan mode bytes.
            // On the tested machines:
            // - 0 means system/automatic mode,
            // - 1 means forced/manual mode.
            for (index, mode) in snapshot.modeBytes.enumerated() {
                try smc.setFanMode(fan: index, mode: mode)
            }

            // Restore the global fan-force mask only when we were able to read it originally.
            // This key is less stable than the per-fan keys, so we treat it as best effort.
            if let manualMask = snapshot.manualMask {
                try? smc.setManualMask(manualMask)
            }

            // Once restore has succeeded, the snapshot is no longer needed.
            // Failure to delete the file should not be treated as a restore failure.
            try? FileManager.default.removeItem(at: AppPaths.stateFile)
            print("Restored system fan control.")
        } catch {
            fputs("Restore failed: \(error)\n", stderr)
        }
    }
}

// The main command runner keeps the end-to-end workflow in a single file.
//
// For a small operational tool like this, local readability is worth a lot:
// a new reader should be able to understand the boost flow, restore flow, and output format
// without navigating across many files.
struct FanPulse {
    static func main() {
        do {
            try run()
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() throws {
        // Default to `boost` because that is the common interactive path.
        let args = Array(CommandLine.arguments.dropFirst())
        let command = Command(rawValue: args.first ?? "boost") ?? .boost

        switch command {
        case .boost:
            let seconds = try parseSeconds(from: args.dropFirst().first)
            try runBoost(seconds: seconds)
        case .restore:
            try runRestore()
        case .status:
            try runStatus()
        case .probe:
            try runProbe()
        }
    }

    private static func runBoost(seconds: Int) throws {
        // Step 1: open SMC and discover the actual fan layout of this machine.
        // We do not hardcode "two fans" in the control flow even though the currently tested
        // machines have two fans, because future actively-cooled Apple Silicon Macs may differ.
        let smc = try AppleSMC()
        let fans = try smc.fanReadings()
        guard !fans.isEmpty else {
            throw SMCError.fanNotFound
        }

        // Step 2: capture the original state before writing anything.
        // This snapshot is the contract that lets us return the machine to its previous state.
        let manualMask = try? smc.readManualMask()
        let snapshot = FanSnapshot(
            timestamp: Date(),
            manualMask: manualMask,
            modeBytes: try fans.map { try smc.readFanMode(fan: $0.index) },
            targetRPMs: fans.map { $0.targetRPM ?? $0.maxRPM ?? 0 }
        )
        try save(snapshot: snapshot)

        // Step 3: install signal-based emergency restore hooks before entering forced mode.
        let coordinator = RestoreCoordinator(smc: smc)
        installSignalHandlers {
            coordinator.restore(from: snapshot)
            exit(130)
        }

        // Step 4: move the machine into forced-fan mode.
        //
        // The order here is deliberate and came from real-machine validation:
        // 1. best-effort global mask (`FS! `) when available,
        // 2. per-fan mode bytes (`F?Md = 1`),
        // 3. per-fan target RPM writes (`F?Tg = max`).
        if let manualMask {
            let newMask = UInt16((1 << fans.count) - 1)
            print(String(format: "Setting FS! from 0x%04x to 0x%04x", manualMask, newMask))
            try smc.setManualMask(newMask)
        }

        for fan in fans {
            try smc.setFanMode(fan: fan.index, mode: 1)
        }

        for fan in fans {
            if let maxRPM = fan.maxRPM {
                try smc.setFanTarget(fan: fan.index, rpm: maxRPM)
            }
        }

        // Step 5: wait briefly before sampling the result.
        // Without this short pause we often read back stale values while the controller is still
        // transitioning.
        Thread.sleep(forTimeInterval: 0.4)

        let boostedFans = try smc.fanReadings()
        print("Boosted fans to max for \(seconds)s.")
        printStatus(boostedFans)

        // Print modes separately because mode confirmation is the easiest way to tell whether
        // the force path was actually accepted by the controller.
        for fan in boostedFans {
            let mode = try smc.readFanMode(fan: fan.index)
            print("Fan \(fan.index): mode \(mode)")
        }

        // Step 6: make sure the normal completion path also restores state.
        defer {
            coordinator.restore(from: snapshot)
        }

        // Step 7: hold the forced state for the requested window.
        Thread.sleep(forTimeInterval: TimeInterval(seconds))
    }

    private static func runRestore() throws {
        // `restore` is only meaningful if we have a saved snapshot from an earlier boost run.
        guard let snapshot = try loadSnapshot() else {
            print("No saved fan state found.")
            return
        }

        let smc = try AppleSMC()
        let coordinator = RestoreCoordinator(smc: smc)
        coordinator.restore(from: snapshot)
    }

    private static func runStatus() throws {
        // Status output is optimized for human readability:
        // global mask if available, then per-fan interpreted values, then per-fan modes.
        let smc = try AppleSMC()
        do {
            let mask = try smc.readManualMask()
            print(String(format: "Manual fan mask: 0x%04x", mask))
        } catch {
            print("Manual fan mask: unavailable (\(error))")
        }

        let readings = try smc.fanReadings()
        printStatus(readings)

        for fan in readings {
            let mode = try smc.readFanMode(fan: fan.index)
            print("Fan \(fan.index): mode \(mode)")
        }
    }

    private static func runProbe() throws {
        // `probe` is intentionally verbose. It is for debugging/research, not end users.
        let smc = try AppleSMC()
        for result in smc.debugProbe(keys: ["FNum", "F0Ac", "F0Mn", "F0Mx", "F0Tg", "F1Ac", "F1Mn", "F1Mx", "F1Tg", "F0Md", "F1Md", "FS! "]) {
            print("\(result.key): \(result.outcome)")
        }
    }

    private static func printStatus(_ fans: [FanReading]) {
        // Keep the output flat and easy to grep.
        for fan in fans {
            let actual = fan.actualRPM.map { String(format: "%.0f", $0) } ?? "n/a"
            let min = fan.minRPM.map { String(format: "%.0f", $0) } ?? "n/a"
            let max = fan.maxRPM.map { String(format: "%.0f", $0) } ?? "n/a"
            let target = fan.targetRPM.map { String(format: "%.0f", $0) } ?? "n/a"
            print("Fan \(fan.index): actual \(actual) RPM, target \(target), min \(min), max \(max)")
        }
    }

    private static func parseSeconds(from value: String?) throws -> Int {
        // The upper bound stays intentionally low: this tool is for short manual cooling bursts,
        // not for replacing the system's thermal manager for long sessions.
        guard let value else { return 20 }
        guard let seconds = Int(value), (1...60).contains(seconds) else {
            throw SMCError.invalidValue("seconds must be an integer between 1 and 60")
        }
        return seconds
    }

    private static func save(snapshot: FanSnapshot) throws {
        // The snapshot is tiny, so a straightforward write is good enough.
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: AppPaths.stateFile)
    }

    private static func loadSnapshot() throws -> FanSnapshot? {
        // A missing file is a normal case, not an error condition.
        guard FileManager.default.fileExists(atPath: AppPaths.stateFile.path) else {
            return nil
        }

        let data = try Data(contentsOf: AppPaths.stateFile)
        return try JSONDecoder().decode(FanSnapshot.self, from: data)
    }

    private static func installSignalHandlers(_ handler: @escaping () -> Void) {
        // We override the default behavior so SIGINT/SIGTERM gives us a chance to restore first.
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        let queue = DispatchQueue(label: "fanpulse.signals")

        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: queue)
        sigint.setEventHandler(handler: handler)
        sigint.resume()

        let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: queue)
        sigterm.setEventHandler(handler: handler)
        sigterm.resume()

        // Keeping references alive prevents the signal sources from being deallocated immediately.
        _ = [sigint, sigterm]
    }
}

// Keep the launch point explicit and easy to spot.
FanPulse.main()
