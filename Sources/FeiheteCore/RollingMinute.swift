import Foundation

public struct RollingMinute {
    public private(set) var times: [Date] = []
    public var window: TimeInterval

    public init(window: TimeInterval = 60) {
        self.window = window
    }

    public var count: Int { times.count }

    public mutating func push(_ t: Date) {
        times.append(t)
        prune(t)
    }

    public mutating func prune(_ t: Date) {
        let floor = t.addingTimeInterval(-window)
        var i = 0
        while i < times.count && times[i] < floor { i += 1 }
        if i > 0 { times.removeFirst(i) }
    }

    public mutating func reset() { times.removeAll() }
}
