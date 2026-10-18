import Darwin

struct NetworkSample {
    var upload: Double      // bytes per second
    var download: Double    // bytes per second
    var sessionUp: UInt64
    var sessionDown: UInt64
}

/// Reads 64-bit interface counters via sysctl(NET_RT_IFLIST2).
/// Only physical interfaces (en*, pdp_ip*) are counted, so VPN tunnels are not double counted.
final class NetworkMonitor {
    private var buffer = [UInt8](repeating: 0, count: 16 * 1024)
    private var included: [UInt16: Bool] = [:]
    private var previous: (up: UInt64, down: UInt64, time: Double)?
    private var sessionUp: UInt64 = 0
    private var sessionDown: UInt64 = 0

    func sample(at time: Double) -> NetworkSample? {
        guard let (up, down) = readCounters() else { return nil }
        defer { previous = (up, down, time) }
        guard let prev = previous, time > prev.time else { return nil }

        let deltaUp = up >= prev.up ? up - prev.up : 0
        let deltaDown = down >= prev.down ? down - prev.down : 0
        sessionUp &+= deltaUp
        sessionDown &+= deltaDown

        let elapsed = time - prev.time
        return NetworkSample(
            upload: Double(deltaUp) / elapsed,
            download: Double(deltaDown) / elapsed,
            sessionUp: sessionUp,
            sessionDown: sessionDown
        )
    }

    private func readCounters() -> (UInt64, UInt64)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0 else { return nil }
        if length > buffer.count {
            buffer = [UInt8](repeating: 0, count: length + 4096)
        }
        length = buffer.count
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return nil }

        var up: UInt64 = 0
        var down: UInt64 = 0
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= length {
                    let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if message.ifm_flags & IFF_UP != 0, isIncluded(index: message.ifm_index) {
                        up &+= message.ifm_data.ifi_obytes
                        down &+= message.ifm_data.ifi_ibytes
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return (up, down)
    }

    private func isIncluded(index: UInt16) -> Bool {
        if let cached = included[index] { return cached }
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        guard if_indextoname(UInt32(index), &name) != nil else { return false }
        let ifName = String(cString: name)
        let result = ifName.hasPrefix("en") || ifName.hasPrefix("pdp_ip")
        included[index] = result
        return result
    }
}
