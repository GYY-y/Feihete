import Foundation

public struct ExportTable {
    public var name: String
    public var header: [String]
    public var rows: [[String]]

    public init(name: String, header: [String], rows: [[String]]) {
        self.name = name
        self.header = header
        self.rows = rows
    }
}
