import Foundation
import Darwin

struct RunningProcess: Identifiable {
    let id: Int32
    let name: String
}

struct EnumerationResult {
    let processes: [RunningProcess]
    let error: String?
}

enum ProcessEnumerator {

    typealias ListPIDs = @convention(c) (
        UnsafeMutableRawPointer?, Int32
    ) -> Int32

    typealias ProcessName = @convention(c) (
        Int32, UnsafeMutableRawPointer?, UInt32
    ) -> Int32

    private static func errnoText(_ code: Int32) -> String {
        if code == 0 {
            return "errno=0 (no error reported)"
        }

        return "errno=\(code): \(String(cString: strerror(code)))"
    }

    static func enumerate() -> EnumerationResult {

        guard let library = dlopen(
            "/usr/lib/libproc.dylib",
            RTLD_NOW
        ) else {
            let message = dlerror().map {
                String(cString: $0)
            } ?? "Unknown error"

            return EnumerationResult(
                processes: [],
                error: "libproc load failed: \(message)"
            )
        }

        defer { dlclose(library) }

        guard
            let listSymbol = dlsym(library, "proc_listallpids"),
            let nameSymbol = dlsym(library, "proc_name")
        else {
            return EnumerationResult(
                processes: [],
                error: "Required libproc symbols unavailable"
            )
        }

        let listPIDs = unsafeBitCast(
            listSymbol,
            to: ListPIDs.self
        )

        let processName = unsafeBitCast(
            nameSymbol,
            to: ProcessName.self
        )

        let errorPointer = __error()

        // Test whether proc_name can identify our own app.
        let ownPID = getpid()
        var ownNameBuffer = [CChar](repeating: 0, count: 256)

        errorPointer.pointee = 0

        let ownNameResult = ownNameBuffer.withUnsafeMutableBufferPointer {
            processName(
                ownPID,
                UnsafeMutableRawPointer($0.baseAddress!),
                UInt32($0.count)
            )
        }

        let ownNameErrno = errorPointer.pointee

        let ownName = ownNameResult > 0
            ? String(cString: ownNameBuffer)
            : "unavailable"

        // First call: ask for the estimated PID count.
        errorPointer.pointee = 0

        let estimate = listPIDs(nil, 0)
        let estimateErrno = errorPointer.pointee

        guard estimate > 0 else {
            return EnumerationResult(
                processes: [],
                error: """
                PID size probe returned \(estimate).
                \(errnoText(estimateErrno))

                Self PID: \(ownPID)
                Self process name: \(ownName)
                Self proc_name result: \(ownNameResult)
                Self proc_name \(errnoText(ownNameErrno))
                """
            )
        }

        // Allocate space for the estimated count plus a margin.
        let capacity = min(max(Int(estimate) + 64, 256), 65536)

        let buffer = UnsafeMutablePointer<Int32>.allocate(
            capacity: capacity
        )

        defer {
            buffer.deallocate()
        }

        buffer.initialize(repeating: 0, count: capacity)

        // Second call: retrieve the actual PIDs.
        let byteCount = Int32(
            capacity * MemoryLayout<Int32>.size
        )

        errorPointer.pointee = 0

        let count = listPIDs(
            UnsafeMutableRawPointer(buffer),
            byteCount
        )

        let listErrno = errorPointer.pointee

        guard count > 0 else {
            return EnumerationResult(
                processes: [],
                error: """
                PID enumeration returned \(count).
                \(errnoText(listErrno))

                Size estimate: \(estimate)
                Self PID: \(ownPID)
                Self process name: \(ownName)
                """
            )
        }

        var results: [RunningProcess] = []

        for index in 0..<min(Int(count), capacity) {
            let pid = buffer[index]
            guard pid > 0 else { continue }

            var nameBuffer = [CChar](
                repeating: 0,
                count: 256
            )

            let nameLength = nameBuffer.withUnsafeMutableBufferPointer {
                processName(
                    pid,
                    UnsafeMutableRawPointer($0.baseAddress!),
                    UInt32($0.count)
                )
            }

            if nameLength > 0 {
                results.append(
                    RunningProcess(
                        id: pid,
                        name: String(cString: nameBuffer)
                    )
                )
            }
        }

        return EnumerationResult(
            processes: results.sorted { $0.id < $1.id },
            error: nil
        )
    }
}
