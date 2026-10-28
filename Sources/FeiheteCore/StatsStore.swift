import Foundation

public final class StatsStore {
    public let daysDirectory: URL

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.autoupdatingCurrent
        return f
    }()

    public static func formatDate(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    public init(directoryName: String = "Feihete") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = base.appendingPathComponent(directoryName)
        daysDirectory = root.appendingPathComponent("days")
        // 旧版本（TapTally 时期）的数据目录一次性迁移到新名字，保留历史数据
        let legacy = base.appendingPathComponent("TapTally")
        if !FileManager.default.fileExists(atPath: root.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: root)
        }
        try? FileManager.default.createDirectory(at: daysDirectory, withIntermediateDirectories: true)
    }

    public func load(_ date: String) -> DayStats {
        let url = daysDirectory.appendingPathComponent("day-\(date).json")
        guard let data = try? Data(contentsOf: url) else { return DayStats(date: date) }
        if let stats = try? Self.decoder.decode(DayStats.self, from: data) { return stats }
        return DayStats(date: date)
    }

    public func save(_ stats: DayStats) {
        let url = daysDirectory.appendingPathComponent("day-\(stats.date).json")
        guard let data = try? Self.encoder.encode(stats) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public func loadAll() -> [DayStats] {
        let files = (try? FileManager.default.contentsOfDirectory(at: daysDirectory, includingPropertiesForKeys: nil)) ?? []
        let days = files
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("day-") }
            .compactMap { url -> DayStats? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? Self.decoder.decode(DayStats.self, from: data)
            }
        return days.sorted { $0.date < $1.date }
    }

    public func clearAll() {
        let files = (try? FileManager.default.contentsOfDirectory(at: daysDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" && file.lastPathComponent.hasPrefix("day-") {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
