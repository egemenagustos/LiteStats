import Foundation

enum Metric: String, CaseIterable {
    case cpu, memory, network, disk
}

enum Language: String, CaseIterable {
    case system, english = "en", turkish = "tr"
}

/// Everything enabled under "Show in Menu Bar", or a single metric only.
enum BarLayout: Equatable {
    case all
    case single(Metric)
}

final class Settings {
    static let shared = Settings()
    static let intervals: [Double] = [1, 2, 5]

    private let defaults = UserDefaults.standard

    private init() {
        var initial: [String: Any] = [
            "interval": 2.0,
            "language": Language.system.rawValue,
            "layout": "all",
            "animations": true,
        ]
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

    var layout: BarLayout {
        get { Metric(rawValue: defaults.string(forKey: "layout") ?? "").map(BarLayout.single) ?? .all }
        set {
            switch newValue {
            case .all: defaults.set("all", forKey: "layout")
            case let .single(metric): defaults.set(metric.rawValue, forKey: "layout")
            }
        }
    }

    /// Metrics shown in the menu bar, in display order.
    var visibleMetrics: [Metric] {
        switch layout {
        case .all: return Metric.allCases.filter(isVisible)
        case let .single(metric): return [metric]
        }
    }

    var animations: Bool {
        get { defaults.bool(forKey: "animations") }
        set { defaults.set(newValue, forKey: "animations") }
    }

    var language: Language {
        get { Language(rawValue: defaults.string(forKey: "language") ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: "language") }
    }
}
