import Darwin
import Foundation

struct MemorySample {
    var used: UInt64
    var total: UInt64
    var usage: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

/// "Memory Used" as Activity Monitor reports it: app memory + wired + compressed.
final class MemoryMonitor {
    private let host = mach_host_self()
    private let pageSize = UInt64(getpagesize())
    private let total = ProcessInfo.processInfo.physicalMemory

    func sample() -> MemorySample? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let app = UInt64(stats.internal_page_count) - min(UInt64(stats.purgeable_count), UInt64(stats.internal_page_count))
        let pages = app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return MemorySample(used: min(pages * pageSize, total), total: total)
    }
}
