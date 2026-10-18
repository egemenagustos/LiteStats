import Foundation

enum Metric: String, CaseIterable {
    case cpu, memory, network, disk
}

enum Language: String, CaseIterable {
    case system, english = "en", turkish = "tr"
}

final class Settings {
    static let shared = Settings()
    static let intervals: [Double] = [1, 2, 5]

    private let defaults = UserDefaults.standard

    private init() {
        var initial: [String: Any] = ["interval": 2.0, "language": Language.system.rawValue]
        for metric in Metric.allCases {
            initial["show.\(metric.rawValue)"] = true
        }
        defaults.register(defaults: initial)
    }

    func isVisible(_ metric: Metric) -> Bool {
        defaults.bool(forKey: "show.\(metric.rawValue)")
    }

    func setVisible(_ metric: Metric, _ visible: Bool) {
        defaults.set(visible, forKey: "show.\(metric.rawValue)")
    }

    var interval: Double {
        get { defaults.double(forKey: "interval") }
        set { defaults.set(newValue, forKey: "interval") }
    }

    var language: Language {
        get { Language(rawValue: defaults.string(forKey: "language") ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: "language") }
    }
}
