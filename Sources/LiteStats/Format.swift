import Foundation

enum Format {
    /// Figure space: same width as a digit in a monospaced-digit font.
    private static let figureSpace: Character = "\u{2007}"

    static func percent(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    /// Compact speed for the menu bar, padded so the width stays stable.
    static func speed(_ bytesPerSecond: Double, padded: Bool = false) -> String {
        let kb = bytesPerSecond / 1000
        let number: String
        let unit: String
        if kb < 1000 {
            number = String(format: "%.0f", locale: .current, kb)
            unit = "KB/s"
        } else if kb < 100_000 {
            number = String(format: "%.1f", locale: .current, kb / 1000)
            unit = "MB/s"
        } else {
            number = String(format: "%.0f", locale: .current, kb / 1000)
            unit = "MB/s"
        }
        guard padded, number.count < 4 else { return "\(number) \(unit)" }
        return String(repeating: figureSpace, count: 4 - number.count) + "\(number) \(unit)"
    }

    /// Very short speed for the stacked menu bar text, e.g. "999K", "1.2M", " 14M",
    /// padded to four characters so the width stays stable.
    static func compactSpeed(_ bytesPerSecond: Double) -> String {
        let kb = max(bytesPerSecond, 0) / 1000
        let text: String
        if kb < 999.5 {
            text = String(format: "%.0fK", locale: .current, kb)
        } else if kb < 9_950 {
            text = String(format: "%.1fM", locale: .current, kb / 1000)
        } else if kb < 999_500 {
            text = String(format: "%.0fM", locale: .current, kb / 1000)
        } else {
            text = String(format: "%.1fG", locale: .current, kb / 1_000_000)
        }
        guard text.count < 4 else { return text }
        return String(repeating: figureSpace, count: 4 - text.count) + text
    }

    /// Decimal units, matching Finder.
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    /// Binary units, matching Activity Monitor.
    static func memory(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }

    /// Whole gigabytes for the menu bar, e.g. "180 GB".
    static func gigabytes(_ value: Int64) -> String {
        let gb = Double(value) / 1_000_000_000
        return String(format: gb < 10 ? "%.1f GB" : "%.0f GB", locale: .current, gb)
    }
}
