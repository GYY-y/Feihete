import SwiftUI
import Charts
import AppKit

struct DashboardView: View {
    @EnvironmentObject var engine: StatsEngine
    @EnvironmentObject private var preferences: AppPreferences
    @State private var range: StatsRange = .today

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            content(engine.stats(for: range), selectedRange: range)
        }
        .navigationTitle("Feihete")
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func content(_ s: DayStats, selectedRange: StatsRange) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $range) {
                    ForEach(StatsRange.allCases) { item in
                        Text(preferences.text.string(item.textKey)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                if !engine.granted {
                    PermissionCard()
                }
                headerStats(s, range: selectedRange)
                HStack(alignment: .top, spacing: 16) {
                    hourlyCard(s)
                    combosCard(s)
                }
                appRankCard(s)
                Text(preferences.text.string(.localOnlyNote))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
        }
    }

    private func headerStats(_ s: DayStats, range: StatsRange) -> some View {
        let periodName = preferences.text.string(range.textKey)
        return HStack(spacing: 16) {
            BigStat(title: "\(periodName) · \(preferences.text.string(.keystrokes))", value: "\(s.keystrokes)", sub: "\(preferences.text.string(.currentSpeed)) \(engine.currentKPM)", valueColor: Color(red: 40 / 255, green: 205 / 255, blue: 65 / 255), subColor: Color(red: 88 / 255, green: 86 / 255, blue: 214 / 255))
            BigStat(title: "\(periodName) · \(preferences.text.string(.characters))", value: "\(s.letters + s.cjk)", sub: "\(preferences.text.string(.chinese)) \(s.cjk) · \(preferences.text.string(.englishCharacters)) \(s.letters)", valueColor: Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255))
            BigStat(title: preferences.text.string(.fastestMinute), value: s.fastMinute.map { "\($0.keys)" } ?? "—", sub: s.fastMinute.map { timeString($0.at) } ?? preferences.text.string(.noData), valueColor: Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255))
        }
    }

    private func hourlyCard(_ s: DayStats) -> some View {
        Card(title: preferences.text.string(.hourlyDistribution)) {
            Chart {
                ForEach(s.hourly.indices, id: \.self) { hour in
                    BarMark(
                        x: .value("小时", hour),
                        y: .value("击键", s.hourly[hour])
                    )
                    .foregroundStyle(hour == currentHour ? Color.accentColor : Color.accentColor.opacity(0.78))
                    .cornerRadius(2)
                }
            }
            .frame(height: 150)
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: Array(stride(from: 0, through: 23, by: 3))) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(String(format: "%02d", hour))
                        }
                    }
                }
            }
        }
    }

    private var currentHour: Int {
        Calendar.autoupdatingCurrent.component(.hour, from: Date())
    }

    private func combosCard(_ s: DayStats) -> some View {
        Card(title: preferences.text.string(.commonCombos)) {
            let top = Array(s.combos.reduce(into: [String: Int]()) { result, item in
                result[Keys.formattedCombo(item.key), default: 0] += item.value
            }.sorted { $0.value > $1.value }.prefix(8))
            if top.isEmpty {
                Text(preferences.text.string(.noData))
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(top.indices, id: \.self) { i in
                            HStack {
                                Text(top[i].0)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("\(top[i].1)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
            }
        }
    }

    private func appRankCard(_ s: DayStats) -> some View {
        let apps = s.apps
            .filter { $0.value.keys > 0 }
            .map { (bundle: $0.key, usage: $0.value) }
            .sorted { $0.usage.keys > $1.usage.keys }
        let top = Array(apps.prefix(8))
        let maxKeys = top.first?.usage.keys ?? 0
        return Card(title: preferences.text.string(.commonApps)) {
            if top.isEmpty {
                Text(preferences.text.string(.noData))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(top, id: \.bundle) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                if let img = engine.icon(for: item.bundle) {
                                    Image(nsImage: img).resizable().frame(width: 18, height: 18)
                                } else {
                                    Image(systemName: "app").frame(width: 18, height: 18)
                                }
                                Text(engine.appName(for: item.bundle, fallback: item.usage.name))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.usage.keys)")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            // 自绘进度条：ProgressView 的线性样式会走材质/
                            // 外观解析路径，在本机构建环境下触发运行时崩溃。
                            MiniBar(ratio: Double(item.usage.keys) / Double(max(maxKeys, 1)))
                        }
                    }
                }
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = preferences.language.locale
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

}

struct PermissionCard: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(preferences.text.string(.accessibilityPermission))
                    .font(.headline)
                Text(preferences.language == .english
                     ? "Open System Settings → Privacy & Security → Accessibility and enable Feihete. Restart the app if counting does not begin."
                     : "打开 系统设置 → 隐私与安全性 → 辅助功能，勾选 Feihete。勾选后若仍未开始统计，请退出并重新打开本应用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(preferences.text.string(.openSystemSettings)) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding(14)
        .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// 轻量进度条：只用静态颜色填充，不触发外观材质解析。
struct MiniBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: max(0, min(1, ratio)) * geo.size.width)
            }
        }
        .frame(height: 4)
    }
}

struct Card<Content: View>: View {    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct BigStat: View {
    let title: String
    let value: String
    let sub: String
    var valueColor: Color = .primary
    var subColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(sub)
                .font(.caption)
                .foregroundStyle(subColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}
