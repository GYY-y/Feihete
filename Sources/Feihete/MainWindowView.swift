import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainWindowView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var router: WindowRouter
    @State private var section: MainSection = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                Text(preferences.text.string(.dashboard)).tag(MainSection.dashboard)
                Text(preferences.text.string(.settings)).tag(MainSection.settings)
                Text(preferences.text.string(.about)).tag(MainSection.about)
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            .padding(.vertical, 14)

            Divider()

            Group {
                switch section {
                case .dashboard:
                    DashboardView()
                case .settings:
                    SettingsView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(preferences.appearance.colorScheme)
        .onReceive(router.$requestedSection.compactMap { $0 }) { requested in
            section = requested
            router.requestedSection = nil
        }
        .onAppear {
            if let requested = router.requestedSection {
                section = requested
                router.requestedSection = nil
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var engine: StatsEngine
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var updateService: UpdateService
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var exportRange: StatsRange = .today
    @State private var showingClearConfirmation = false
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(preferences.text.string(.settings))
                    .font(.title2.weight(.semibold))

                VStack(spacing: 0) {
                    SettingRow(symbol: "globe", color: .blue, title: preferences.text.string(.language)) {
                        Picker("", selection: $preferences.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 190)
                    }
                    Divider().padding(.leading, 54)
                    SettingRow(symbol: "circle.lefthalf.filled", color: .indigo, title: preferences.text.string(.appearance)) {
                        Picker("", selection: $preferences.appearance) {
                            Text(preferences.text.string(.system)).tag(AppAppearance.system)
                            Text(preferences.text.string(.light)).tag(AppAppearance.light)
                            Text(preferences.text.string(.dark)).tag(AppAppearance.dark)
                        }
                        .labelsHidden()
                        .frame(width: 190)
                    }
                    Divider().padding(.leading, 54)
                    SettingRow(symbol: "power", color: .green, title: preferences.text.string(.launchAtLogin)) {
                        Toggle("", isOn: Binding(
                            get: { launchAtLogin },
                            set: { on in
                                LaunchAtLogin.set(on)
                                launchAtLogin = LaunchAtLogin.isEnabled
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    Divider().padding(.leading, 54)
                    SettingRow(symbol: "arrow.clockwise", color: .cyan, title: preferences.text.string(.autoCheckUpdates)) {
                        Toggle("", isOn: $preferences.autoCheckUpdates)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

                Text(preferences.text.string(.export))
                    .font(.title3.weight(.semibold))
                VStack(spacing: 0) {
                    SettingRow(symbol: "calendar", color: .purple, title: preferences.text.string(.exportRange)) {
                        Picker("", selection: $exportRange) {
                            ForEach(StatsRange.allCases) { range in
                                Text(preferences.text.string(range.textKey)).tag(range)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                    Divider().padding(.leading, 54)
                    SettingRow(symbol: "tablecells", color: .orange, title: preferences.text.string(.exportExcel)) {
                        Button(preferences.text.string(.export)) { exportXlsx() }
                    }
                    Divider().padding(.leading, 54)
                    SettingRow(symbol: "folder", color: .cyan, title: preferences.text.string(.dataFolder)) {
                        Button(preferences.text.string(.open)) { engine.openDataFolder() }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

                Text(preferences.text.string(.clearData))
                    .font(.title3.weight(.semibold))
                SettingRow(symbol: "trash", color: .red, title: preferences.text.string(.clearData), subtitle: preferences.text.string(.clearDataDescription)) {
                    Button(preferences.text.string(.clear)) {
                        showingClearConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
        }
        .alert(preferences.text.string(.clearDataTitle), isPresented: $showingClearConfirmation) {
            Button(preferences.text.string(.clear), role: .destructive) { engine.clearAllData() }
            Button(preferences.text.string(.cancel), role: .cancel) {}
        } message: {
            Text(preferences.text.string(.clearDataMessage))
        }
        .alert(preferences.text.string(.exportFailed), isPresented: .init(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button(preferences.text.string(.ok), role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private func exportXlsx() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx") ?? .data]
        panel.nameFieldStringValue = "Feihete统计.xlsx"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = XLSXExporter.make(tables: Exporter.tablesFrom(days: engine.days(for: exportRange)))
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            exportError = error.localizedDescription
        }
    }
}

struct AboutView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var updateService: UpdateService

    var body: some View {
        VStack(spacing: 14) {
            if let image = AppBranding.logo(size: NSSize(width: 150, height: 88)) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 88)
            } else {
                Image(systemName: "keyboard")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
            }
            Text("Feihete")
                .font(.title.weight(.bold))
            Text(preferences.text.string(.aboutDescription))
                .foregroundStyle(.secondary)
            Text(preferences.text.string(.version))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(preferences.text.string(.builtForMac))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button(updateButtonTitle) {
                updateService.checkForUpdates()
            }
            .buttonStyle(.borderedProminent)
            .disabled(updateService.state == .checking)
            if case let .available(update) = updateService.state {
                Button(preferences.text.string(.downloadUpdate)) {
                    updateService.openUpdate(update)
                }
                .buttonStyle(.link)
            } else if let status = updateStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var updateButtonTitle: String {
        updateService.state == .checking
            ? preferences.text.string(.checkingForUpdates)
            : preferences.text.string(.checkForUpdates)
    }

    private var updateStatus: String? {
        switch updateService.state {
        case .upToDate: return preferences.text.string(.upToDate)
        case .unavailable: return preferences.text.string(.updateSourceUnavailable)
        case let .available(update): return "\(preferences.text.string(.updateAvailable)): v\(update.version)"
        case let .failed(message): return message
        case .idle, .checking: return nil
        }
    }
}

struct SettingRow<Accessory: View>: View {
    let symbol: String
    let color: Color
    let title: String
    let subtitle: String?
    @ViewBuilder let accessory: Accessory

    init(symbol: String, color: Color, title: String, subtitle: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.symbol = symbol
        self.color = color
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            accessory
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
