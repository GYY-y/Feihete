import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case traditionalHongKong = "zh-Hant-HK"
    case traditionalTaiwan = "zh-Hant-TW"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        case .traditionalHongKong: return "繁體中文（香港）"
        case .traditionalTaiwan: return "繁體中文（台灣）"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Keys.language) }
    }
    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    @Published var autoCheckUpdates: Bool {
        didSet { UserDefaults.standard.set(autoCheckUpdates, forKey: Keys.autoCheckUpdates) }
    }

    private enum Keys {
        static let language = "Feihete.language"
        static let appearance = "Feihete.appearance"
        static let autoCheckUpdates = "Feihete.autoCheckUpdates"
        // 旧版本（TapTally 时期）的键名，仅用于首次读取迁移
        static let legacyLanguage = "TapTally.language"
        static let legacyAppearance = "TapTally.appearance"
        static let legacyAutoCheckUpdates = "TapTally.autoCheckUpdates"
    }

    private static func storedString(_ key: String, legacy: String) -> String? {
        UserDefaults.standard.string(forKey: key) ?? UserDefaults.standard.string(forKey: legacy)
    }

    private init() {
        language = AppLanguage(rawValue: Self.storedString(Keys.language, legacy: Keys.legacyLanguage) ?? "") ?? .simplifiedChinese
        appearance = AppAppearance(rawValue: Self.storedString(Keys.appearance, legacy: Keys.legacyAppearance) ?? "") ?? .system
        autoCheckUpdates = UserDefaults.standard.object(forKey: Keys.autoCheckUpdates) as? Bool
            ?? (UserDefaults.standard.object(forKey: Keys.legacyAutoCheckUpdates) as? Bool ?? false)
    }

    var text: AppText { AppText(language: language) }
}

struct AppText {
    enum Key {
        case dashboard, settings, about, quit
        case todayKeystrokes, totalCharacters, currentSpeed, fastestMinute
        case chinese, englishCharacters, noData, hourlyDistribution, commonCombos, commonApps
        case appRanking, exportExcel, dataFolder, accessibilityPermission, openSystemSettings
        case localOnlyNote, language, appearance, launchAtLogin, autoCheckUpdates, clearData, clearDataDescription
        case export, exportRange, open, clear, cancel, clearDataTitle, clearDataMessage, exportFailed, ok
        case system, light, dark, aboutDescription, version, builtForMac
        case permissionBadgeGranted, permissionBadgeMissing
        case today, last7Days, last30Days, keystrokes, characters
        case checkForUpdates, checkingForUpdates, upToDate, updateAvailable, updateSourceUnavailable, downloadUpdate
    }

    let language: AppLanguage

    func string(_ key: Key) -> String {
        switch language {
        case .simplifiedChinese:
            return simplified(key)
        case .english:
            return english(key)
        case .traditionalHongKong:
            return traditional(key, region: .hongKong)
        case .traditionalTaiwan:
            return traditional(key, region: .taiwan)
        }
    }

    private func simplified(_ key: Key) -> String {
        switch key {
        case .dashboard: return "仪表盘"
        case .settings: return "设置"
        case .about: return "关于"
        case .quit: return "退出"
        case .todayKeystrokes: return "今日击键"
        case .totalCharacters: return "今日总字数"
        case .currentSpeed: return "当前速度"
        case .fastestMinute: return "最快一分钟"
        case .chinese: return "中文"
        case .englishCharacters: return "英文"
        case .noData: return "暂无数据"
        case .hourlyDistribution: return "时段分布（24 小时）"
        case .commonCombos: return "常用组合键"
        case .commonApps: return "常用应用"
        case .appRanking: return "应用排名（今日击键）"
        case .exportExcel: return "导出 Excel（xlsx）"
        case .dataFolder: return "数据文件夹"
        case .accessibilityPermission: return "需要「辅助功能」权限"
        case .openSystemSettings: return "打开系统设置"
        case .localOnlyNote: return "统计只保存在本机。中文按输入法上屏的字数统计，英文按按键统计；不含空格、方向键与长按重复。"
        case .language: return "语言"
        case .appearance: return "外观"
        case .launchAtLogin: return "开机启动"
        case .autoCheckUpdates: return "自动检查更新"
        case .clearData: return "清空数据"
        case .clearDataDescription: return "删除本机保存的所有统计数据"
        case .export: return "导出"
        case .exportRange: return "导出范围"
        case .open: return "打开"
        case .clear: return "清空"
        case .cancel: return "取消"
        case .clearDataTitle: return "清空全部数据？"
        case .clearDataMessage: return "此操作会删除本机保存的所有统计数据，且无法恢复。"
        case .exportFailed: return "导出失败"
        case .ok: return "好"
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        case .aboutDescription: return "轻量、纯本地、隐私优先的键盘统计工具。"
        case .version: return "版本 0.1.0"
        case .builtForMac: return "为 macOS 打造"
        case .permissionBadgeGranted: return "● 已获键盘监听权限"
        case .permissionBadgeMissing: return "● 未获权限"
        case .today: return "今天"
        case .last7Days: return "过去 7 天"
        case .last30Days: return "过去 30 天"
        case .keystrokes: return "击键"
        case .characters: return "总字数"
        case .checkForUpdates: return "检查更新"
        case .checkingForUpdates: return "正在检查更新…"
        case .upToDate: return "已是最新版本"
        case .updateAvailable: return "发现新版本"
        case .updateSourceUnavailable: return "更新源尚未配置"
        case .downloadUpdate: return "下载更新"
        }
    }

    private func english(_ key: Key) -> String {
        switch key {
        case .dashboard: return "Dashboard"
        case .settings: return "Settings"
        case .about: return "About"
        case .quit: return "Quit"
        case .todayKeystrokes: return "Today's Keystrokes"
        case .totalCharacters: return "Today's Characters"
        case .currentSpeed: return "Current Speed"
        case .fastestMinute: return "Fastest Minute"
        case .chinese: return "Chinese"
        case .englishCharacters: return "English"
        case .noData: return "No Data"
        case .hourlyDistribution: return "Hourly Distribution (24 hours)"
        case .commonCombos: return "Common Shortcuts"
        case .commonApps: return "Common Apps"
        case .appRanking: return "App Ranking (Today's Keystrokes)"
        case .exportExcel: return "Export Excel (xlsx)"
        case .dataFolder: return "Data Folder"
        case .accessibilityPermission: return "Accessibility Permission Required"
        case .openSystemSettings: return "Open System Settings"
        case .localOnlyNote: return "Stats stay on this Mac. Chinese counts committed input characters; English counts printable key presses. Spaces, arrows, and key repeats are excluded."
        case .language: return "Language"
        case .appearance: return "Appearance"
        case .launchAtLogin: return "Launch at Login"
        case .autoCheckUpdates: return "Check for Updates Automatically"
        case .clearData: return "Clear Data"
        case .clearDataDescription: return "Delete all statistics stored on this Mac"
        case .export: return "Export"
        case .exportRange: return "Export Range"
        case .open: return "Open"
        case .clear: return "Clear"
        case .cancel: return "Cancel"
        case .clearDataTitle: return "Clear all data?"
        case .clearDataMessage: return "This deletes all statistics stored on this Mac and cannot be undone."
        case .exportFailed: return "Export Failed"
        case .ok: return "OK"
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .aboutDescription: return "A lightweight, local-first, privacy-focused keyboard statistics tool."
        case .version: return "Version 0.1.0"
        case .builtForMac: return "Made for macOS"
        case .permissionBadgeGranted: return "● Keyboard monitoring enabled"
        case .permissionBadgeMissing: return "● Permission missing"
        case .today: return "Today"
        case .last7Days: return "Past 7 Days"
        case .last30Days: return "Past 30 Days"
        case .keystrokes: return "Keystrokes"
        case .characters: return "Characters"
        case .checkForUpdates: return "Check for Updates"
        case .checkingForUpdates: return "Checking for Updates…"
        case .upToDate: return "You're up to date"
        case .updateAvailable: return "Update Available"
        case .updateSourceUnavailable: return "Update source is not configured"
        case .downloadUpdate: return "Download Update"
        }
    }

    private enum Region { case hongKong, taiwan }

    private func traditional(_ key: Key, region: Region) -> String {
        let hongKong = region == .hongKong
        switch key {
        case .dashboard: return "儀表板"
        case .settings: return "設定"
        case .about: return "關於"
        case .quit: return hongKong ? "離開" : "退出"
        case .todayKeystrokes: return "今日擊鍵"
        case .totalCharacters: return "今日總字數"
        case .currentSpeed: return "目前速度"
        case .fastestMinute: return "最快一分鐘"
        case .chinese: return "中文"
        case .englishCharacters: return "英文"
        case .noData: return "暫無資料"
        case .hourlyDistribution: return "時段分佈（24 小時）"
        case .commonCombos: return "常用組合鍵"
        case .commonApps: return "常用應用程式"
        case .appRanking: return "應用程式排名（今日擊鍵）"
        case .exportExcel: return "匯出 Excel（xlsx）"
        case .dataFolder: return "資料夾"
        case .accessibilityPermission: return "需要「輔助使用」權限"
        case .openSystemSettings: return hongKong ? "開啟系統設定" : "打開系統設定"
        case .localOnlyNote: return hongKong ? "統計資料只會儲存在本機。中文按輸入法上屏字數統計，英文按按鍵統計；不包括空格、方向鍵與長按重複。" : "統計資料只會儲存在本機。中文按輸入法上屏字數統計，英文按按鍵統計；不含空格、方向鍵與長按重複。"
        case .language: return "語言"
        case .appearance: return "外觀"
        case .launchAtLogin: return hongKong ? "登入時啟動" : "開機自動啟動"
        case .autoCheckUpdates: return hongKong ? "自動檢查更新" : "自動檢查更新"
        case .clearData: return "清除資料"
        case .clearDataDescription: return "刪除儲存在本機的所有統計資料"
        case .export: return "匯出"
        case .exportRange: return "匯出範圍"
        case .open: return hongKong ? "開啟" : "打開"
        case .clear: return "清除"
        case .cancel: return "取消"
        case .clearDataTitle: return "清除所有資料？"
        case .clearDataMessage: return "這會刪除儲存在本機的所有統計資料，而且無法復原。"
        case .exportFailed: return "匯出失敗"
        case .ok: return "好"
        case .system: return "跟隨系統"
        case .light: return "淺色"
        case .dark: return "深色"
        case .aboutDescription: return "輕量、純本機、重視私隱的鍵盤統計工具。"
        case .version: return "版本 0.1.0"
        case .builtForMac: return "為 macOS 打造"
        case .permissionBadgeGranted: return "● 已取得鍵盤監察權限"
        case .permissionBadgeMissing: return "● 未取得權限"
        case .today: return hongKong ? "今天" : "今天"
        case .last7Days: return hongKong ? "過去 7 天" : "過去 7 天"
        case .last30Days: return hongKong ? "過去 30 天" : "過去 30 天"
        case .keystrokes: return "擊鍵"
        case .characters: return "總字數"
        case .checkForUpdates: return hongKong ? "檢查更新" : "檢查更新"
        case .checkingForUpdates: return hongKong ? "正在檢查更新…" : "正在檢查更新…"
        case .upToDate: return hongKong ? "已是最新版本" : "已是最新版本"
        case .updateAvailable: return hongKong ? "發現新版本" : "發現新版本"
        case .updateSourceUnavailable: return hongKong ? "尚未設定更新來源" : "尚未設定更新來源"
        case .downloadUpdate: return hongKong ? "下載更新" : "下載更新"
        }
    }
}
