import Foundation

public struct AppUsage: Codable, Equatable {
    public var name: String
    public var keys: Int
    public var letters: Int
    public var cjk: Int

    public init(name: String, keys: Int = 0, letters: Int = 0, cjk: Int = 0) {
        self.name = name
        self.keys = keys
        self.letters = letters
        self.cjk = cjk
    }
}

public struct FastMinute: Codable, Equatable {
    public var keys: Int
    public var at: Date

    public init(keys: Int, at: Date) {
        self.keys = keys
        self.at = at
    }
}

public struct DayStats: Codable {
    public var date: String
    public var keystrokes: Int
    public var letters: Int
    public var cjk: Int
    public var hourly: [Int]
    public var apps: [String: AppUsage]
    public var combos: [String: Int]
    public var fastMinute: FastMinute?
    public var updatedAt: Date

    public init(date: String) {
        self.date = date
        self.keystrokes = 0
        self.letters = 0
        self.cjk = 0
        self.hourly = Array(repeating: 0, count: 24)
        self.apps = [:]
        self.combos = [:]
        self.fastMinute = nil
        self.updatedAt = Date()
    }

    public init(date: String, keystrokes: Int, letters: Int, cjk: Int,
                hourly: [Int], apps: [String: AppUsage], combos: [String: Int],
                fastMinute: FastMinute?, updatedAt: Date) {
        self.date = date
        self.keystrokes = keystrokes
        self.letters = letters
        self.cjk = cjk
        self.hourly = hourly.count == 24 ? hourly : Array(repeating: 0, count: 24)
        self.apps = apps
        self.combos = combos
        self.fastMinute = fastMinute
        self.updatedAt = updatedAt
    }

    public static func aggregate(_ days: [DayStats], date: String) -> DayStats {
        var result = DayStats(date: date)
        for day in days {
            result.keystrokes += day.keystrokes
            result.letters += day.letters
            result.cjk += day.cjk
            for hour in result.hourly.indices where day.hourly.indices.contains(hour) {
                result.hourly[hour] += day.hourly[hour]
            }
            for (bundle, usage) in day.apps {
                var merged = result.apps[bundle] ?? AppUsage(name: usage.name)
                if merged.name.isEmpty { merged.name = usage.name }
                merged.keys += usage.keys
                merged.letters += usage.letters
                merged.cjk += usage.cjk
                result.apps[bundle] = merged
            }
            for (combo, count) in day.combos {
                result.combos[combo, default: 0] += count
            }
            if let fast = day.fastMinute,
               result.fastMinute == nil || fast.keys > result.fastMinute!.keys {
                result.fastMinute = fast
            }
            if day.updatedAt > result.updatedAt { result.updatedAt = day.updatedAt }
        }
        return result
    }

    public mutating func addKeystroke(hour: Int, bundle: String, appName: String) {
        keystrokes += 1
        if hourly.indices.contains(hour) { hourly[hour] += 1 }
        var usage = apps[bundle] ?? AppUsage(name: appName)
        usage.keys += 1
        apps[bundle] = usage
        updatedAt = Date()
    }

    public mutating func addLetters(_ n: Int, bundle: String, appName: String) {
        guard n > 0 else { return }
        letters += n
        var usage = apps[bundle] ?? AppUsage(name: appName)
        usage.letters += n
        apps[bundle] = usage
        updatedAt = Date()
    }

    public mutating func addCJK(_ n: Int, bundle: String, appName: String) {
        guard n > 0 else { return }
        cjk += n
        var usage = apps[bundle] ?? AppUsage(name: appName)
        usage.cjk += n
        apps[bundle] = usage
        updatedAt = Date()
    }

    public mutating func addCombo(_ combo: String) {
        combos[combo, default: 0] += 1
        updatedAt = Date()
    }

    public mutating func bumpFastMinute(keys: Int, at: Date) {
        if let f = fastMinute {
            guard keys > f.keys else { return }
        }
        fastMinute = FastMinute(keys: keys, at: at)
        updatedAt = Date()
    }
}

public struct Snapshot {
    public var today: DayStats
    public var currentKPM: Int
    public var granted: Bool

    public init(today: DayStats, currentKPM: Int, granted: Bool) {
        self.today = today
        self.currentKPM = currentKPM
        self.granted = granted
    }
}
