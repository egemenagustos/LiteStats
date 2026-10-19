import Foundation

/// English and Turkish strings, kept in code so the app has no resource lookups
/// and the language can be switched at runtime without a restart.
enum L10n {
    private static let english: [String: String] = [
        "cpu": "CPU",
        "cpu.detail": "CPU: %@  (User %@, System %@)",
        "memory": "Memory",
        "memory.detail": "Memory: %@ / %@  (%@)",
        "network.detail": "Upload: %@   Download: %@",
        "network.session": "Since launch: Up %@   Down %@",
        "disk.detail": "SSD: %@ used of %@  (%@)",
        "disk.free": "Free space: %@",
        "network": "Network",
        "disk": "SSD",
        "show": "Show in Menu Bar",
        "layout": "Menu Bar Layout",
        "layout.all": "All Metrics",
        "layout.only": "Only %@",
        "animations": "Animated Icons",
        "interval": "Update Interval",
        "seconds": "%d s",
        "language": "Language",
        "language.system": "System",
        "launchAtLogin": "Launch at Login",
        "activityMonitor": "Open Activity Monitor",
        "quit": "Quit LiteStats",
        "waiting": "Measuring...",
    ]

    private static let turkish: [String: String] = [
        "cpu": "CPU",
        "cpu.detail": "CPU: %@  (Kullanıcı %@, Sistem %@)",
        "memory": "Bellek",
        "memory.detail": "Bellek: %@ / %@  (%@)",
        "network.detail": "Yükleme: %@   İndirme: %@",
        "network.session": "Açılıştan beri: Yükleme %@   İndirme %@",
        "disk.detail": "SSD: %@ / %@ dolu  (%@)",
        "disk.free": "Boş alan: %@",
        "network": "Ağ",
        "disk": "SSD",
        "show": "Menü Çubuğunda Göster",
        "layout": "Menü Çubuğu Düzeni",
        "layout.all": "Tüm Metrikler",
        "layout.only": "Yalnızca %@",
        "animations": "Animasyonlu İkonlar",
        "interval": "Yenileme Aralığı",
        "seconds": "%d sn",
        "language": "Dil",
        "language.system": "Sistem",
        "launchAtLogin": "Girişte Başlat",
        "activityMonitor": "Etkinlik Monitörü'nü Aç",
        "quit": "LiteStats'tan Çık",
        "waiting": "Ölçülüyor...",
    ]

    private static var table = english

    static func reload() {
        let code: String
        switch Settings.shared.language {
        case .system: code = Locale.preferredLanguages.first ?? "en"
        case let language: code = language.rawValue
        }
        table = code.hasPrefix("tr") ? turkish : english
    }

    static func t(_ key: String) -> String {
        table[key] ?? english[key] ?? key
    }

    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }
}
