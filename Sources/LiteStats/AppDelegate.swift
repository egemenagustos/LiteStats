import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let barView = StatusBarView()

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let diskMonitor = DiskMonitor()

    private var cpu: CPUSample?
    private var memory: MemorySample?
    private var network: NetworkSample?
    private var disk: DiskSample?

    private var timer: Timer?
    private var lastDiskUpdate = -Double.infinity
    private let diskInterval = 30.0
    private var lastTitle = ""
    private var menuIsOpen = false

    private var cpuItem = NSMenuItem()
    private var memoryItem = NSMenuItem()
    private var networkItem = NSMenuItem()
    private var sessionItem = NSMenuItem()
    private var diskItem = NSMenuItem()
    private var diskFreeItem = NSMenuItem()
    private var showItem = NSMenuItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        L10n.reload()
        if let button = statusItem.button {
            barView.frame = button.bounds
            barView.autoresizingMask = [.width, .height]
            barView.animationsEnabled = settings.animations
            button.addSubview(barView)
        }
        buildMenu()
        updateLength()
        tick()
        startTimer()
    }

    // MARK: - Sampling

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: settings.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = settings.interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        cpu = cpuMonitor.sample() ?? cpu
        memory = memoryMonitor.sample() ?? memory
        network = networkMonitor.sample(at: now) ?? network
        if now - lastDiskUpdate >= diskInterval {
            disk = diskMonitor.sample() ?? disk
            lastDiskUpdate = now
        }
        updateTitle()
        if menuIsOpen { updateDetails() }
    }

    // MARK: - Menu bar

    /// Spoken text for VoiceOver, since the menu bar itself is mostly icons.
    private func makeTitle(_ metrics: [Metric]) -> String {
        metrics.map { metric in
            switch metric {
            case .cpu: return "CPU \(cpu.map { Format.percent($0.total) } ?? "-")"
            case .memory: return "RAM \(memory.map { Format.percent($0.usage) } ?? "-")"
            case .network:
                let up = network.map { Format.speed($0.upload) } ?? "-"
                let down = network.map { Format.speed($0.download) } ?? "-"
                return "\u{2191}\(up) \u{2193}\(down)"
            case .disk: return "SSD \(disk.map { Format.percent($0.usage) } ?? "-")"
            }
        }.joined(separator: ", ")
    }

    /// Fixed length avoids a full menu bar relayout on every update, which is
    /// by far the most expensive part of running a status item.
    private func updateLength() {
        let metrics = settings.visibleMetrics
        barView.metrics = metrics
        guard !metrics.isEmpty else {
            statusItem.length = NSStatusItem.squareLength
            return
        }
        statusItem.length = ceil(StatusBarView.width(for: metrics)) + 8
    }

    private func updateTitle() {
        barView.update(
            cpu: cpu?.total,
            memory: memory?.usage,
            upload: network?.upload,
            download: network?.download,
            disk: disk?.usage
        )
        let title = makeTitle(settings.visibleMetrics)
        guard title != lastTitle, let button = statusItem.button else { return }
        lastTitle = title

        button.setAccessibilityLabel(title.isEmpty ? "LiteStats" : title)
        if title.isEmpty, button.image == nil {
            button.image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "LiteStats")
        } else if !title.isEmpty, button.image != nil {
            button.image = nil
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        cpuItem = infoItem()
        memoryItem = infoItem()
        networkItem = infoItem()
        sessionItem = infoItem()
        diskItem = infoItem()
        diskFreeItem = infoItem()
        [cpuItem, memoryItem, networkItem, sessionItem, diskItem, diskFreeItem].forEach(menu.addItem)

        menu.addItem(.separator())

        let showMenu = NSMenu()
        for metric in Metric.allCases {
            let item = NSMenuItem(title: L10n.t(metric.rawValue), action: #selector(toggleMetric(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = metric.rawValue
            item.state = settings.isVisible(metric) ? .on : .off
            showMenu.addItem(item)
        }
        showItem = submenuItem(L10n.t("show"), showMenu)
        showItem.isEnabled = settings.layout == .all
        menu.addItem(showItem)

        let layoutMenu = NSMenu()
        let allItem = NSMenuItem(title: L10n.t("layout.all"), action: #selector(setLayout(_:)), keyEquivalent: "")
        allItem.target = self
        allItem.representedObject = "all"
        allItem.state = settings.layout == .all ? .on : .off
        layoutMenu.addItem(allItem)
        layoutMenu.addItem(.separator())
        for metric in Metric.allCases {
            let item = NSMenuItem(title: L10n.t("layout.only", L10n.t(metric.rawValue)), action: #selector(setLayout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = metric.rawValue
            item.state = settings.layout == .single(metric) ? .on : .off
            layoutMenu.addItem(item)
        }
        menu.addItem(submenuItem(L10n.t("layout"), layoutMenu))

        let animationsItem = NSMenuItem(title: L10n.t("animations"), action: #selector(toggleAnimations(_:)), keyEquivalent: "")
        animationsItem.target = self
        animationsItem.state = settings.animations ? .on : .off
        menu.addItem(animationsItem)

        let intervalMenu = NSMenu()
        for interval in Settings.intervals {
            let item = NSMenuItem(title: L10n.t("seconds", Int(interval)), action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            item.state = settings.interval == interval ? .on : .off
            intervalMenu.addItem(item)
        }
        menu.addItem(submenuItem(L10n.t("interval"), intervalMenu))

        let languageMenu = NSMenu()
        for language in Language.allCases {
            let title: String
            switch language {
            case .system: title = L10n.t("language.system")
            case .english: title = "English"
            case .turkish: title = "Türkçe"
            }
            let item = NSMenuItem(title: title, action: #selector(setLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = settings.language == language ? .on : .off
            languageMenu.addItem(item)
        }
        menu.addItem(submenuItem(L10n.t("language"), languageMenu))

        let loginItem = NSMenuItem(title: L10n.t("launchAtLogin"), action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let activityItem = NSMenuItem(title: L10n.t("activityMonitor"), action: #selector(openActivityMonitor), keyEquivalent: "")
        activityItem.target = self
        menu.addItem(activityItem)

        let quitItem = NSMenuItem(title: L10n.t("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateDetails()
    }

    private func infoItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t("waiting"), action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func submenuItem(_ title: String, _ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private func updateDetails() {
        if let cpu {
            setInfo(cpuItem, L10n.t("cpu.detail", Format.percent(cpu.total), Format.percent(cpu.user), Format.percent(cpu.system)))
        }
        if let memory {
            setInfo(memoryItem, L10n.t("memory.detail", Format.memory(memory.used), Format.memory(memory.total), Format.percent(memory.usage)))
        }
        if let network {
            setInfo(networkItem, L10n.t("network.detail", Format.speed(network.upload), Format.speed(network.download)))
            setInfo(sessionItem, L10n.t("network.session", Format.bytes(Int64(network.sessionUp)), Format.bytes(Int64(network.sessionDown))))
        }
        if let disk {
            setInfo(diskItem, L10n.t("disk.detail", Format.bytes(disk.used), Format.bytes(disk.total), Format.percent(disk.usage)))
            setInfo(diskFreeItem, L10n.t("disk.free", Format.bytes(disk.available)))
        }
    }

    private func setInfo(_ item: NSMenuItem, _ text: String) {
        guard item.title != text else { return }
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ])
        item.title = text
    }

    nonisolated func menuWillOpen(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            menuIsOpen = true
            disk = diskMonitor.sample() ?? disk
            lastDiskUpdate = ProcessInfo.processInfo.systemUptime
            updateDetails()
        }
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        MainActor.assumeIsolated { menuIsOpen = false }
    }

    // MARK: - Actions

    @objc private func toggleMetric(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let metric = Metric(rawValue: raw) else { return }
        let visible = !settings.isVisible(metric)
        settings.setVisible(metric, visible)
        sender.state = visible ? .on : .off
        updateLength()
        updateTitle()
    }

    @objc private func setLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        settings.layout = Metric(rawValue: raw).map(BarLayout.single) ?? .all
        sender.menu?.items.forEach { $0.state = $0 === sender ? .on : .off }
        showItem.isEnabled = settings.layout == .all
        updateLength()
        updateTitle()
    }

    @objc private func toggleAnimations(_ sender: NSMenuItem) {
        settings.animations.toggle()
        sender.state = settings.animations ? .on : .off
        barView.animationsEnabled = settings.animations
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? Double else { return }
        settings.interval = interval
        sender.menu?.items.forEach { $0.state = $0 === sender ? .on : .off }
        startTimer()
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let language = Language(rawValue: raw) else { return }
        settings.language = language
        L10n.reload()
        buildMenu()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSSound.beep()
        }
        sender.state = service.status == .enabled ? .on : .off
    }

    @objc private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
