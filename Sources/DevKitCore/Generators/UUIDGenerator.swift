import Foundation

public struct UUIDGeneratorTool: Sendable {
    public init() {}

    public enum FormatOption: String, Sendable, CaseIterable {
        case standard = "标准格式 (带连字符)"
        case noHyphens = "无连字符"
        case uppercase = "大写标准格式"
        case uppercaseNoHyphens = "大写无连字符"
    }

    public static func generate(count: Int = 1, format: FormatOption = .standard) -> [String] {
        let safeCount = max(1, min(count, 100))
        return (0..<safeCount).map { _ in
            let uuid = UUID().uuidString
            switch format {
            case .standard:
                return uuid.lowercased()
            case .noHyphens:
                return uuid.replacingOccurrences(of: "-", with: "").lowercased()
            case .uppercase:
                return uuid.uppercased()
            case .uppercaseNoHyphens:
                return uuid.replacingOccurrences(of: "-", with: "").uppercased()
            }
        }
    }
}
