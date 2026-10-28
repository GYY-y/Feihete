import SwiftUI
import AppKit

struct LiveView: View {
    @EnvironmentObject var engine: StatsEngine
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var router: WindowRouter
    @EnvironmentObject private var updateService: UpdateService
    @Environment(\.openWindow) private var openWindow
    @State private var hoveredAction: String?
    @State private var hoveredUpdate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 仅数据行每秒刷新；操作按钮放在外面，
            // 避免视图重建吞掉鼠标点击（否则「退出」按钮经常点不中）。
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                statsRows(engine.snapshot())
            }
            // 自动检查更新发现新版本时在此提示,点击直达下载
            if case let .available(update) = updateService.state {
                Button {
                    updateService.openUpdate(update)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(preferences.text.string(.updateAvailable) + ": v\(update.version)")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        Text(preferences.text.string(.downloadUpdate))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hoveredUpdate = $0 }
                .opacity(hoveredUpdate ? 1 : 0.85)
            }
            actionRow(preferences.text.string(.settings), shortcut: ",") {
                router.show(.settings)
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
            actionRow(preferences.text.string(.quit), shortcut: "Q") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    @ViewBuilder
    private func statsRows(_ s: Snapshot) -> some View {
        let comboCounts = s.today.combos.reduce(into: [String: Int]()) { result, item in
            result[Keys.formattedCombo(item.key), default: 0] += item.value
        }
        let topCombo = comboCounts.max { $0.value < $1.value }
        let topApp = s.today.apps.filter { $0.value.keys > 0 }.max { $0.value.keys < $1.value.keys }

        VStack(alignment: .leading, spacing: 10) {
            if !s.granted {
                Text(preferences.language == .english
                     ? "Enable Feihete in System Settings → Privacy & Security → Accessibility"
                     : "需要辅助功能权限，请在系统设置中勾选 Feihete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
            }
            row(preferences.text.string(.todayKeystrokes), "\(s.today.keystrokes)")
            row(preferences.text.string(.totalCharacters), "\(s.today.letters + s.today.cjk)（\(preferences.text.string(.chinese)) \(s.today.cjk) · \(preferences.text.string(.englishCharacters)) \(s.today.letters)）")
            row(preferences.text.string(.fastestMinute), s.today.fastMinute.map { "\($0.keys)" } ?? "—")
            row(preferences.text.string(.currentSpeed), "\(s.currentKPM)")
            row(preferences.text.string(.commonCombos), topCombo?.key ?? "—")
            row(preferences.text.string(.commonApps), topApp.map { engine.appName(for: $0.key, fallback: $0.value.name) } ?? "—")
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }

    private func actionRow(_ title: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .foregroundStyle(hoveredAction == title ? Color.accentColor : .secondary)
                Spacer()
                Text("⌘\(shortcut)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .onHover { isHovered in
            hoveredAction = isHovered ? title : nil
        }
        .keyboardShortcut(shortcut == "," ? "," : "q", modifiers: [.command])
    }
}
