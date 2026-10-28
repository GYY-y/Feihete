import Foundation

func argValue(_ flag: String) -> String? {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
    return args[i + 1]
}

if CommandLine.arguments.contains("--export-demo") {
    func day(_ n: Int) -> DayStats {
        let idx = Calendar.current.date(byAdding: .day, value: -n, to: Date())!
        var s = DayStats(date: StatsStore.formatDate(idx))
        s.keystrokes = 15000 + n * 512
        s.letters = 3000 + n * 90
        s.cjk = 1200 + n * 30
        s.hourly = (0..<24).map { h in (h % 3 == 0 ? 800 : 200) + h * (h % 2 == 0 ? 11 : 7) }
        s.apps = [
            "com.tencent.wechat": AppUsage(name: "微信", keys: 9000 + n, letters: 1000 + n, cjk: 800 + n),
            "com.apple.Notes": AppUsage(name: "备忘录", keys: 3000 + n, letters: 500 + n, cjk: 300 + n)
        ]
        s.combos = ["⌘C": 320, "⌘V": 210, "⌘⇧4": 88]
        s.fastMinute = FastMinute(keys: 97 + n, at: Date())
        return s
    }

    let days = (0..<3).map(day)
    let tables = Exporter.tablesFrom(days: days)
    let xlsxPath = argValue("--xlsx") ?? "/tmp/feihete-demo.xlsx"
    try XLSXExporter.make(tables: tables).write(to: URL(fileURLWithPath: xlsxPath))
    print("xlsx=\(xlsxPath)")
} else {
    print("usage: taptool --export-demo [--xlsx path]")
}
