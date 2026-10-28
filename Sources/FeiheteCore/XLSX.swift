import Foundation

enum XLSXExporter {
    static func make(tables: [ExportTable]) -> Data {
        var entries = [
            ZipWriter.Entry(name: "[Content_Types].xml", data: Data(contentTypes(tables.count).utf8)),
            ZipWriter.Entry(name: "_rels/.rels", data: Data(rootRels.utf8)),
            ZipWriter.Entry(name: "xl/workbook.xml", data: Data(workbookXML(tables).utf8)),
            ZipWriter.Entry(name: "xl/_rels/workbook.xml.rels", data: Data(workbookRels(tables.count).utf8))
        ]
        for (i, table) in tables.enumerated() {
            entries.append(ZipWriter.Entry(name: "xl/worksheets/sheet\(i + 1).xml", data: Data(sheetXML(table).utf8)))
        }
        return ZipWriter.archive(entries: entries)
    }

    private static func contentTypes(_ sheetCount: Int) -> String {
        var sheetParts = ""
        for i in 1...max(1, sheetCount) {
            sheetParts += "<Override PartName=\"/xl/worksheets/sheet\(i).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        \(sheetParts)
        </Types>
        """
    }

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """

    private static func workbookXML(_ tables: [ExportTable]) -> String {
        let sheets = tables.enumerated().map { pair -> String in
            let (i, table) = pair
            return "<sheet name=\"\(escape(table.name))\" sheetId=\"\(i + 1)\" r:id=\"rId\(i + 1)\"/>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>\(sheets)</sheets></workbook>
        """
    }

    private static func workbookRels(_ count: Int) -> String {
        let rels = (1...max(1, count)).map { i in
            "<Relationship Id=\"rId\(i)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i).xml\"/>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(rels)</Relationships>
        """
    }

    private static func sheetXML(_ table: ExportTable) -> String {
        var body = "<row r=\"1\">"
        for (i, head) in table.header.enumerated() {
            body += "<c r=\"\(column(i + 1))1\" t=\"inlineStr\"><is><t>\(escape(head))</t></is></c>"
        }
        body += "</row>"
        for (ri, row) in table.rows.enumerated() {
            body += "<row r=\"\(ri + 2)\">"
            for (ci, value) in row.enumerated() {
                let ref = "\(column(ci + 1))\(ri + 2)"
                if let n = asNumber(value) {
                    body += "<c r=\"\(ref)\"><v>\(n)</v></c>"
                } else {
                    body += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t>\(escape(value))</t></is></c>"
                }
            }
            body += "</row>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(body)</sheetData></worksheet>
        """
    }

    private static func asNumber(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if let i = Int(t) { return String(i) }
        if let d = Double(t) {
            let decimalSeparator = Locale.current.decimalSeparator
            if decimalSeparator == nil || decimalSeparator == "." || !t.contains(decimalSeparator!) {
                return d == d.rounded(.towardZero) && abs(d) < 1e15 && !t.contains(".") ? String(Int(d)) : String(d)
            }
        }
        return nil
    }

    static func column(_ index: Int) -> String {
        var n = index
        var out = ""
        while n > 0 {
            let rem = (n - 1) % 26
            out = String(UnicodeScalar(Int("A".unicodeScalars.first!.value) + rem)!) + out
            n = (n - rem - 1) / 26
        }
        return out
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "\u{26}amp;")
            .replacingOccurrences(of: "<", with: "\u{3C}lt;")
            .replacingOccurrences(of: ">", with: "\u{3E}gt;")
            .replacingOccurrences(of: "\"", with: "\u{22}quot;")
    }
}
