import Foundation

public struct TimestampConversionResult: Sendable {
    public let seconds: Int64
    public let milliseconds: Int64
    public let iso8601: String
    public let localFormatted: String
    public let utcFormatted: String
    public let beijingFormatted: String
    public let newYorkFormatted: String
    public let tokyoFormatted: String
    public let relativeFormatted: String
    public let isDetectedMilliseconds: Bool

    public init(
        seconds: Int64,
        milliseconds: Int64,
        iso8601: String,
        localFormatted: String,
        utcFormatted: String,
        beijingFormatted: String,
        newYorkFormatted: String,
        tokyoFormatted: String,
        relativeFormatted: String,
        isDetectedMilliseconds: Bool = false
    ) {
        self.seconds = seconds
        self.milliseconds = milliseconds
        self.iso8601 = iso8601
        self.localFormatted = localFormatted
        self.utcFormatted = utcFormatted
        self.beijingFormatted = beijingFormatted
        self.newYorkFormatted = newYorkFormatted
        self.tokyoFormatted = tokyoFormatted
        self.relativeFormatted = relativeFormatted
        self.isDetectedMilliseconds = isDetectedMilliseconds
    }
}

public struct TimestampConverterTool: Sendable {
    public init() {}

    public static func current() -> TimestampConversionResult {
        return convert(date: Date())
    }

    public static func convert(date: Date, isMilliseconds: Bool = false) -> TimestampConversionResult {
        let sec = Int64(date.timeIntervalSince1970)
        let ms = Int64(date.timeIntervalSince1970 * 1000)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoStr = isoFormatter.string(from: date)

        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        localFormatter.timeZone = TimeZone.current
        let localStr = localFormatter.string(from: date)

        let utcFormatter = DateFormatter()
        utcFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let utcStr = utcFormatter.string(from: date)

        let bjFormatter = DateFormatter()
        bjFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        bjFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)
        let bjStr = bjFormatter.string(from: date)

        let nyFormatter = DateFormatter()
        nyFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        nyFormatter.timeZone = TimeZone(identifier: "America/New_York") ?? TimeZone(secondsFromGMT: -5 * 3600)
        let nyStr = nyFormatter.string(from: date)

        let tokyoFormatter = DateFormatter()
        tokyoFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        tokyoFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? TimeZone(secondsFromGMT: 9 * 3600)
        let tokyoStr = tokyoFormatter.string(from: date)

        let relFormatter = RelativeDateTimeFormatter()
        relFormatter.unitsStyle = .full
        let relStr = relFormatter.localizedString(for: date, relativeTo: Date())

        return TimestampConversionResult(
            seconds: sec,
            milliseconds: ms,
            iso8601: isoStr,
            localFormatted: localStr,
            utcFormatted: utcStr,
            beijingFormatted: bjStr,
            newYorkFormatted: nyStr,
            tokyoFormatted: tokyoStr,
            relativeFormatted: relStr,
            isDetectedMilliseconds: isMilliseconds
        )
    }

    public static func convert(timestampString: String) -> Result<TimestampConversionResult, DevKitError> {
        let trimmed = timestampString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Double(trimmed) else {
            return .failure(DevKitError("请输入有效的数值时间戳"))
        }

        let isMs = trimmed.count >= 13
        let date: Date
        if isMs {
            date = Date(timeIntervalSince1970: number / 1000.0)
        } else {
            date = Date(timeIntervalSince1970: number)
        }

        return .success(convert(date: date, isMilliseconds: isMs))
    }

    public static func parseDate(dateString: String) -> Result<TimestampConversionResult, DevKitError> {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd"
        ]

        let formatter = DateFormatter()
        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: trimmed) {
                return .success(convert(date: date))
            }
        }
        return .failure(DevKitError("无法解析日期格式，支持格式示例：2026-10-12 12:00:00"))
    }
}
