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
        UnsafeMutableRawPointer?,
        Int32
    ) -> Int32

    typealias ProcessName = @convention(c) (
        Int32,
        UnsafeMutableRawPointer?,
        UInt32
    ) -> Int32

    static func enumerate() -> EnumerationResult {

        guard let library = dlopen(
            "/usr/lib/libproc.dylib",
            RTLD_NOW
        ) else {
            let message = dlerror().map {
                String(cString: $0)
            } ?? "Unknown dlopen error"

            return EnumerationResult(
                processes: [],
                error: "Could not load libproc: \(message)"
            )
        }

        defer {
            dlclose(library)
        }

        guard
            let listSymbol = dlsym(library, "proc_listallpids"),
            let nameSymbol = dlsym(library, "proc_name")
        else {
            return EnumerationResult(
                processes: [],
                error: "Required process APIs are unavailable"
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

        let capacity = 8192

        let buffer = UnsafeMutablePointer<Int32>.allocate(
            capacity: capacity
        )

        defer {
            buffer.deallocate()
        }

        buffer.initialize(
            repeating: 0,
            count: capacity
        )

        let byteCount = Int32(
            capacity * MemoryLayout<Int32>.size
        )

        let count = listPIDs(
            UnsafeMutableRawPointer(buffer),
            byteCount
        )

        guard count > 0 else {
            return EnumerationResult(
                processes: [],
                error: "proc_listallpids returned \(count)"
            )
        }

        var processes: [RunningProcess] = []

        for index in 0..<min(Int(count), capacity) {

            let pid = buffer[index]

            guard pid > 0 else {
                continue
            }

            var nameBuffer = [CChar](
                repeating: 0,
                count: 256
            )

            let result = nameBuffer.withUnsafeMutableBufferPointer {
                processName(
                    pid,
                    UnsafeMutableRawPointer($0.baseAddress!),
                    UInt32($0.count)
                )
            }

            if result > 0 {
                let name = String(cString: nameBuffer)

                processes.append(
                    RunningProcess(
                        id: pid,
                        name: name
                    )
                )
            }
        }

        return EnumerationResult(
            processes: processes.sorted {
                $0.id < $1.id
            },
            error: nil
        )
    }
}
