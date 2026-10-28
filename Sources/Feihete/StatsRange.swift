import Foundation

enum StatsRange: String, CaseIterable, Identifiable {
    case today
    case last7Days
    case last30Days

    var id: String { rawValue }

    var calendarDays: Int {
        switch self {
        case .today: return 1
        case .last7Days: return 7
        case .last30Days: return 30
        }
    }

    var textKey: AppText.Key {
        switch self {
        case .today: return .today
        case .last7Days: return .last7Days
        case .last30Days: return .last30Days
        }
    }
}
