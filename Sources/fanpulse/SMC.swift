import Foundation
import IOKit

// Errors are worded for shell users, not just for developers.
// This tool is often run from Terminal or from a `.command` launcher, so failures should still
// be understandable without attaching a debugger.
enum SMCError: Error, CustomStringConvertible {
    case serviceNotFound
    case openFailed(kern_return_t)
    case callFailed(kern_return_t, selector: UInt32, command: UInt8, key: String)
    case invalidKey(String)
    case invalidValue(String)
    case fanNotFound

    var description: String {
        switch self {
        case .serviceNotFound:
            return "Unable to find AppleSMC."
        case .openFailed(let kr):
            return "Failed to open AppleSMC connection: \(String(cString: mach_error_string(kr)))."
        case .callFailed(let kr, let selector, let command, let key):
            return "SMC call failed for key \(key) (selector \(selector), command \(command)): \(String(cString: mach_error_string(kr)))."
        case .invalidKey(let key):
            return "Invalid SMC key: \(key)."
        case .invalidValue(let value):
            return "Invalid value: \(value)."
        case .fanNotFound:
            return "No fans were reported by AppleSMC."
        }
    }
}

// Normalized fan view used by the higher-level command logic.
//
// The rest of the tool should not have to think in raw byte payloads or key names once the
// data has been translated into this structure.
struct FanReading {
    let index: Int
    let actualRPM: Double?
    let minRPM: Double?
    let maxRPM: Double?
    let targetRPM: Double?
}

// Snapshot of the original machine state before a boost run.
//
// This is the minimal set of values we need to restore the previous configuration:
// - global fan force mask when readable,
// - per-fan mode bytes,
// - per-fan target RPMs.
struct FanSnapshot: Codable {
    let timestamp: Date
    let manualMask: UInt16?
    let modeBytes: [UInt8]
    let targetRPMs: [Double]
}

// Metadata returned by an SMC key-info request.
// `size` and `type` are especially important because key payload layouts differ.
private struct SMCKeyInfo {
    let size: UInt32
    let type: UInt32
    let attributes: UInt8
}

// Full record used by generic read paths and by the `probe` subcommand.
private struct SMCDataRecord {
    let key: String
    let size: UInt32
    let type: String
    let bytes: [UInt8]
}

// One human-readable probe line.
struct ProbeResult {
    let key: String
    let outcome: String
}

// AppleSMC is the only place where raw hardware access is performed.
//
// Design goals for this wrapper:
// 1. concentrate all hardcoded offsets in one place,
// 2. convert raw buffers into typed Swift values as soon as possible,
// 3. keep the rest of the program free from pointer-heavy IOKit code.
final class AppleSMC {
    // Through real-machine validation, selector 2 is the struct method that handled the working
    // read/write path for the tested Apple Silicon Macs.
    private static let selector: UInt32 = 2

    // Size of the input/output buffer used with the working AppleSMC user-client path.
    private static let ioStructSize = 0x50

    // Command byte values used by the SMC user client.
    private static let keyInfoCommand: UInt8 = 9
    private static let readCommand: UInt8 = 5
    private static let writeCommand: UInt8 = 6

    // Offsets inside the 0x50 (80-byte) input/output structure.
    //
    // Layout (reconstructed from real-machine validation on Apple Silicon):
    //
    //   Offset  Size  Field
    //   0x00    4     Key (FourCC, big-endian packed into UInt32)
    //   0x04    24    (reserved / unknown)
    //   0x1c    4     Key info: payload size in bytes
    //   0x20    4     Key info: data type (FourCC, e.g. "flt ", "fpe2")
    //   0x24    1     Key info: attribute flags
    //   0x25    3     (reserved / unknown)
    //   0x28    1     Result code (0 = success)
    //   0x29    1     Status code (0 = success)
    //   0x2a    1     Command byte (5=read, 6=write, 9=keyInfo)
    //   0x2b    1     (reserved / unknown)
    //   0x2c    4     Data (used by some 32-bit value paths)
    //   0x30    32    Data payload area (read/write bytes)
    //
    // These names are intentionally explicit because this mapping is the hardest part to
    // reconstruct later if it is not documented carefully.
    private static let offsetKey = 0x00
    private static let offsetKeyInfoSize = 0x1c
    private static let offsetKeyInfoType = 0x20
    private static let offsetKeyInfoAttrs = 0x24
    private static let offsetResult = 0x28
    private static let offsetStatus = 0x29
    private static let offsetCommand = 0x2a
    private static let offsetData32 = 0x2c
    private static let offsetBytesRead = 0x30
    private static let offsetBytesWrite = 0x30

    private var connect: io_connect_t = 0

    init() throws {
        // Find the AppleSMC service and open a connection that stays alive for this wrapper's
        // lifetime. Higher-level code assumes "one command invocation -> one short-lived SMC
        // session".
        let iterator = try Self.matchingIterator()
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            throw SMCError.serviceNotFound
        }
        defer { IOObjectRelease(service) }

        let kr = IOServiceOpen(service, mach_task_self_, 0, &connect)
        guard kr == KERN_SUCCESS else {
            throw SMCError.openFailed(kr)
        }
    }

    deinit {
        // Closing the connection explicitly keeps the hardware-facing resource lifecycle obvious.
        if connect != 0 {
            IOServiceClose(connect)
        }
    }

    func readFanCount() throws -> Int {
        // `FNum` is the canonical fan-count key.
        let bytes = try readKeyBytes("FNum")
        guard let count = bytes.first, count > 0 else {
            throw SMCError.fanNotFound
        }
        return Int(count)
    }

    func fanReadings() throws -> [FanReading] {
        // Build one normalized reading per fan so callers never need to hand-assemble key names.
        let count = try readFanCount()
        return try (0..<count).map { fan in
            FanReading(
                index: fan,
                actualRPM: try readNumeric(key: String(format: "F%dAc", fan)),
                minRPM: try readNumeric(key: String(format: "F%dMn", fan)),
                maxRPM: try readNumeric(key: String(format: "F%dMx", fan)),
                targetRPM: try readNumeric(key: String(format: "F%dTg", fan))
            )
        }
    }

    func readManualMask() throws -> UInt16 {
        // `FS! ` turned out to be less reliable via the normal keyInfo path, so we fall back to
        // direct reads with explicit assumed sizes.
        do {
            let bytes = try readKeyBytesFixedSize("FS! ", size: 2)
            if bytes.count >= 2 {
                return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            }
        } catch {
            // Fall through to single-byte attempt; the 2-byte path is not stable on all machines.
        }

        let bytes = try readKeyBytesFixedSize("FS! ", size: 1)
        return UInt16(bytes.first ?? 0)
    }

    func setManualMask(_ mask: UInt16) throws {
        // The tested machines responded correctly to a two-byte big-endian payload here.
        let payload = [UInt8((mask >> 8) & 0xff), UInt8(mask & 0xff)]
        try writeKey("FS! ", payload: payload)
    }

    func readFanMode(fan index: Int) throws -> UInt8 {
        // `F?Md` is the per-fan manual/system mode key.
        let bytes = try readKeyBytes(String(format: "F%dMd", index))
        return bytes.first ?? 0
    }

    func setFanMode(fan index: Int, mode: UInt8) throws {
        // Single-byte mode write.
        try writeKey(String(format: "F%dMd", index), payload: [mode])
    }

    func setFanTarget(fan index: Int, rpm: Double) throws {
        // `F?Tg` is not universally the same type across every Mac.
        // On the tested Apple Silicon machines it is exposed as `flt `, but we keep support for
        // `fpe2` because older references and other machines may still use it.
        let key = String(format: "F%dTg", index)
        let info = try keyInfo(for: key)
        let type = decodeFourCC(info.type)

        let payload: [UInt8]
        switch type {
        case "flt ":
            var value = Float(rpm).bitPattern.littleEndian
            payload = withUnsafeBytes(of: &value) { Array($0) }
        case "fpe2":
            // fpe2 = fixed-point with 2 fractional bits (14.2 format), so multiply by 4.
            let raw = UInt16(max(0, rpm * 4.0).rounded())
            payload = [UInt8((raw >> 8) & 0xff), UInt8(raw & 0xff)]
        default:
            throw SMCError.invalidValue("unsupported target type \(type)")
        }

        try writeKey(key, payload: payload)
    }

    func readNumeric(key: String) throws -> Double? {
        // Generic numeric decoder used by status output and fan summarization.
        let record = try readRecord(key: key)
        let bytes = record.bytes
        let type = record.type

        switch type {
        case "ui8 ":
            return Double(bytes.first ?? 0)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = bytes.withUnsafeBytes { $0.load(as: UInt32.self) }
            return Double(Float(bitPattern: UInt32(littleEndian: bits)))
        case "fpe2":
            // fpe2 = 14.2 fixed-point, so the raw big-endian UInt16 is divided by 4.
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        default:
            return nil
        }
    }

    func debugProbe(keys: [String]) -> [ProbeResult] {
        // Probe should keep going even if individual keys fail.
        keys.map { key in
            do {
                let info = try keyInfo(for: key)
                let record = try readRecord(key: key, info: info)
                let preview = record.bytes.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " ")
                return ProbeResult(
                    key: key,
                    outcome: "size=\(record.size) type=\(record.type) attrs=\(info.attributes) bytes=[\(preview)]"
                )
            } catch {
                return ProbeResult(key: key, outcome: "\(error)")
            }
        }
    }

    private func keyInfo(for key: String) throws -> SMCKeyInfo {
        // Ask the controller how this key wants to be interpreted.
        var input = blankIOBuffer()
        writeUInt32(try encodeKey(key), to: &input, offset: Self.offsetKey)
        input[Self.offsetCommand] = Self.keyInfoCommand

        let output = try call(input: input, key: key, command: Self.keyInfoCommand, enforceStatus: true)
        return SMCKeyInfo(
            size: readUInt32(from: output, offset: Self.offsetKeyInfoSize),
            type: readUInt32(from: output, offset: Self.offsetKeyInfoType),
            attributes: output[Self.offsetKeyInfoAttrs]
        )
    }

    private func readKeyBytes(_ key: String, info: SMCKeyInfo? = nil) throws -> [UInt8] {
        try readRecord(key: key, info: info).bytes
    }

    private func readKeyBytesFixedSize(_ key: String, size: UInt32) throws -> [UInt8] {
        // Special-case read path that bypasses keyInfo and uses a caller-supplied size instead.
        // Used only when metadata cannot be trusted (e.g. the `FS! ` manual mask key).
        var input = blankIOBuffer()
        writeUInt32(try encodeKey(key), to: &input, offset: Self.offsetKey)
        writeUInt32(size, to: &input, offset: Self.offsetKeyInfoSize)
        input[Self.offsetCommand] = Self.readCommand

        let output = try call(input: input, key: key, command: Self.readCommand, enforceStatus: true)
        let bounded = min(Int(size), 32)
        return Array(output[Self.offsetBytesRead..<(Self.offsetBytesRead + bounded)])
    }

    private func readRecord(key: String, info: SMCKeyInfo? = nil) throws -> SMCDataRecord {
        // Standard read path:
        // 1. obtain key metadata,
        // 2. issue a read using the declared size,
        // 3. return only the meaningful payload bytes.
        let info = try info ?? keyInfo(for: key)

        var input = blankIOBuffer()
        writeUInt32(try encodeKey(key), to: &input, offset: Self.offsetKey)
        writeUInt32(info.size, to: &input, offset: Self.offsetKeyInfoSize)
        input[Self.offsetCommand] = Self.readCommand

        let output = try call(input: input, key: key, command: Self.readCommand)
        let size = min(Int(info.size), 32)
        return SMCDataRecord(
            key: key,
            size: info.size,
            type: decodeFourCC(info.type),
            bytes: Array(output[Self.offsetBytesRead..<(Self.offsetBytesRead + size)])
        )
    }

    private func writeKey(_ key: String, payload: [UInt8]) throws {
        // Bound payload size to the space available in the SMC I/O struct.
        let bounded = Array(payload.prefix(32))

        // Normal keys are validated against their reported size. `FS! ` remains a special-case
        // key because its metadata behavior did not match the observed working write path.
        let size: UInt32
        if key == "FS! " {
            size = UInt32(bounded.count)
        } else {
            let current = try readRecord(key: key)
            guard Int(current.size) == bounded.count else {
                throw SMCError.invalidValue("payload size \(bounded.count) does not match current size \(current.size) for \(key)")
            }
            size = current.size
        }

        var input = blankIOBuffer()
        writeUInt32(try encodeKey(key), to: &input, offset: Self.offsetKey)
        writeUInt32(size, to: &input, offset: Self.offsetKeyInfoSize)
        input[Self.offsetCommand] = Self.writeCommand
        replaceBytes(in: &input, offset: Self.offsetBytesWrite, with: bounded)

        // Status enforcement remains disabled for writes because some successful real-machine
        // transitions were not accompanied by status bytes we fully trusted.
        _ = try call(input: input, key: key, command: Self.writeCommand, enforceStatus: false)
    }

    private func call(input: [UInt8], key: String, command: UInt8, enforceStatus: Bool = false) throws -> [UInt8] {
        // This is the only raw IOKit struct call in the project.
        // Everything above this point should think in terms of keys and typed values.
        var output = blankIOBuffer()
        let inputSize = input.count
        var outputSize = output.count

        let kr = input.withUnsafeBytes { inputRaw in
            output.withUnsafeMutableBytes { outputRaw in
                IOConnectCallStructMethod(
                    connect,
                    Self.selector,
                    inputRaw.baseAddress,
                    inputSize,
                    outputRaw.baseAddress,
                    &outputSize
                )
            }
        }

        guard kr == KERN_SUCCESS else {
            throw SMCError.callFailed(kr, selector: Self.selector, command: command, key: key)
        }

        // Some paths are strict about status bytes, some are intentionally tolerant.
        if enforceStatus && (output[Self.offsetResult] != 0 || output[Self.offsetStatus] != 0) {
            throw SMCError.callFailed(kIOReturnError, selector: Self.selector, command: command, key: key)
        }

        return output
    }

    private static func matchingIterator() throws -> io_iterator_t {
        // Locate the AppleSMC service by name.
        guard let matching = IOServiceMatching("AppleSMC") else {
            throw SMCError.serviceNotFound
        }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            throw SMCError.openFailed(kr)
        }
        return iterator
    }

    private func blankIOBuffer() -> [UInt8] {
        // Centralizing zeroed buffer allocation avoids mismatched sizes between call sites.
        Array(repeating: 0, count: Self.ioStructSize)
    }

    private func encodeKey(_ key: String) throws -> UInt32 {
        // SMC keys are four-character codes packed into a UInt32.
        let bytes = Array(key.utf8)
        guard bytes.count == 4 else {
            throw SMCError.invalidKey(key)
        }

        return UInt32(bytes[0]) << 24 |
            UInt32(bytes[1]) << 16 |
            UInt32(bytes[2]) << 8 |
            UInt32(bytes[3])
    }

    private func decodeFourCC(_ value: UInt32) -> String {
        // Useful for diagnostics and for choosing the correct payload decoder.
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff),
        ]
        return String(decoding: bytes, as: UTF8.self)
    }

    private func writeUInt32(_ value: UInt32, to buffer: inout [UInt8], offset: Int) {
        // These fields are stored little-endian in the working struct layout we use.
        let little = value.littleEndian
        withUnsafeBytes(of: little) { raw in
            buffer.replaceSubrange(offset..<(offset + 4), with: raw)
        }
    }

    private func readUInt32(from buffer: [UInt8], offset: Int) -> UInt32 {
        // Mirror of `writeUInt32`.
        let raw = buffer[offset..<(offset + 4)].withUnsafeBytes { $0.load(as: UInt32.self) }
        return UInt32(littleEndian: raw)
    }

    private func replaceBytes(in buffer: inout [UInt8], offset: Int, with bytes: [UInt8]) {
        // Small helper used to keep buffer writes readable at call sites.
        buffer.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
    }
}
