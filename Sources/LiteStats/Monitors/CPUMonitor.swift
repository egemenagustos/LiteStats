import Darwin

struct CPUSample {
    var user: Double
    var system: Double
    var total: Double { user + system }
}

/// Total CPU load from a single HOST_CPU_LOAD_INFO call (all cores aggregated).
final class CPUMonitor {
    private let host = mach_host_self()
    private var previous: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    func sample() -> CPUSample? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let ticks = info.cpu_ticks
        let current = (user: ticks.0, system: ticks.1, idle: ticks.2, nice: ticks.3)
        defer { previous = current }
        guard let prev = previous else { return nil }

        let user = Double(current.user &- prev.user) + Double(current.nice &- prev.nice)
        let system = Double(current.system &- prev.system)
        let idle = Double(current.idle &- prev.idle)
        let total = user + system + idle
        guard total > 0 else { return nil }
        return CPUSample(user: user / total, system: system / total)
    }
}
