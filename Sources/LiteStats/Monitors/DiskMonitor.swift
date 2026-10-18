import Foundation

struct DiskSample {
    var total: Int64
    var available: Int64
    var used: Int64 { max(total - available, 0) }
    var usage: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

/// Startup volume capacity. Uses the same "available" figure Finder shows
/// (includes purgeable space that macOS frees on demand).
final class DiskMonitor {
    private let root = URL(fileURLWithPath: "/")
    private let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]

    func sample() -> DiskSample? {
        var url = root
        url.removeAllCachedResourceValues()
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return DiskSample(total: Int64(total), available: available)
    }
}
