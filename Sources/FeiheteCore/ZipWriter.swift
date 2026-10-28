import Foundation

enum ZipWriter {
    struct Entry {
        let name: String
        let data: Data

        init(name: String, data: Data) {
            self.name = name
            self.data = data
        }
    }

    static func archive(entries: [Entry]) -> Data {
        var out = Data()
        var central = Data()
        var offsets: [Int] = []
        let (dosTime, dosDate) = dosDateTime(Date())

        for entry in entries {
            let nameBytes = Data(entry.name.utf8)
            let crc = crc32(entry.data)
            offsets.append(out.count)

            var header = Data()
            header.appendLE(UInt32(0x04034b50))
            header.appendLE(UInt16(20))
            header.appendLE(UInt16(0))
            header.appendLE(UInt16(0))
            header.appendLE(dosTime)
            header.appendLE(dosDate)
            header.appendLE(crc)
            header.appendLE(UInt32(entry.data.count))
            header.appendLE(UInt32(entry.data.count))
            header.appendLE(UInt16(nameBytes.count))
            header.appendLE(UInt16(0))
            out.append(header)
            out.append(nameBytes)
            out.append(entry.data)

            var c = Data()
            c.appendLE(UInt32(0x02014b50))
            c.appendLE(UInt16(20))
            c.appendLE(UInt16(20))
            c.appendLE(UInt16(0))
            c.appendLE(UInt16(0))
            c.appendLE(dosTime)
            c.appendLE(dosDate)
            c.appendLE(crc)
            c.appendLE(UInt32(entry.data.count))
            c.appendLE(UInt32(entry.data.count))
            c.appendLE(UInt16(nameBytes.count))
            c.appendLE(UInt16(0))
            c.appendLE(UInt16(0))
            c.appendLE(UInt16(0))
            c.appendLE(UInt16(0))
            c.appendLE(UInt32(0))
            c.appendLE(UInt32(offsets.last!))
            central.append(c)
            central.append(nameBytes)
        }

        let centralOffset = out.count
        out.append(central)

        var eocd = Data()
        eocd.appendLE(UInt32(0x06054b50))
        eocd.appendLE(UInt16(0))
        eocd.appendLE(UInt16(0))
        eocd.appendLE(UInt16(entries.count))
        eocd.appendLE(UInt16(entries.count))
        eocd.appendLE(UInt32(central.count))
        eocd.appendLE(UInt32(centralOffset))
        eocd.appendLE(UInt16(0))
        out.append(eocd)
        return out
    }

    private static func dosDateTime(_ date: Date) -> (UInt16, UInt16) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max(1980, c.year ?? 1980)
        let month = c.month ?? 1
        let day = c.day ?? 1
        let hour = c.hour ?? 0
        let minute = c.minute ?? 0
        let halfSecond = max(0, (c.second ?? 0) / 2)
        let dosDate = UInt16((year - 1980) * 512 + month * 32 + day)
        let dosTime = UInt16(hour * 2048 + minute * 32 + halfSecond)
        return (dosTime, dosDate)
    }

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

extension Data {
    mutating func appendLE(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
