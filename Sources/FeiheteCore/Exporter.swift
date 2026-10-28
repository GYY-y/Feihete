import Foundation

public enum Exporter {
    public static func tablesFrom(days: [DayStats]) -> [ExportTable] {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }()
        let sorted = days.sorted { $0.date < $1.date }

        var rows1: [[String]] = []
        for d in sorted {
            rows1.append([
                d.date,
                String(d.keystrokes),
                String(d.letters),
                String(d.cjk),
                String(d.letters + d.cjk),
                d.fastMinute.map { String($0.keys) } ?? "",
                d.fastMinute.map { timeFormatter.string(from: $0.at) } ?? ""
            ])
        }
        let t1 = ExportTable(
            name: "每日汇总",
            header: ["日期", "击键", "英文字符", "中文字符", "总字数", "最快一分钟", "达成时间"],
            rows: rows1
        )

        var rows2: [[String]] = []
        for d in sorted {
            let apps = d.apps.sorted { $0.value.keys > $1.value.keys }
            for (bundle, usage) in apps {
                rows2.append([d.date, usage.name.isEmpty ? bundle : usage.name, String(usage.keys), String(usage.letters), String(usage.cjk)])
            }
        }
        let t2 = ExportTable(name: "应用统计", header: ["日期", "应用", "击键", "英文字符", "中文字符"], rows: rows2)

        var rows3: [[String]] = []
        for d in sorted {
            let combos = d.combos.sorted { $0.value > $1.value }
            for (combo, count) in combos {
                rows3.append([d.date, Keys.formattedCombo(combo), String(count)])
            }
        }
        let t3 = ExportTable(name: "组合键", header: ["日期", "组合键", "次数"], rows: rows3)

        var rows4: [[String]] = []
        for d in sorted {
            for (hour, value) in d.hourly.enumerated() where value > 0 {
                rows4.append([d.date, String(hour), String(value)])
            }
        }
        let t4 = ExportTable(name: "时段分布", header: ["日期", "小时", "击键"], rows: rows4)

        return [t1, t2, t3, t4]
    }
}
