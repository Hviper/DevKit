import Foundation

public enum ToolCategory: String, Sendable, CaseIterable, Identifiable {
    case diff = "文本比对 (Diff)"
    case url = "URL 编解码"
    case base64 = "Base64 编解码"
    case hash = "哈希生成 (Hash)"
    case json = "代码格式化 (Format)"
    case uuid = "UUID 生成器"
    case timestamp = "时间戳转换"
    case regex = "正则表达式"
    case jwt = "JWT 解析器"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .diff: return "square.split.2x1"
        case .url: return "link"
        case .base64: return "lock.rotation"
        case .hash: return "number"
        case .json: return "curlybraces"
        case .uuid: return "tag"
        case .timestamp: return "clock"
        case .regex: return "character.cursor.ibeam"
        case .jwt: return "key.horizontal"
        }
    }

    public var shortcutNumber: Int {
        switch self {
        case .diff: return 1
        case .url: return 2
        case .base64: return 3
        case .hash: return 4
        case .json: return 5
        case .uuid: return 6
        case .timestamp: return 7
        case .regex: return 8
        case .jwt: return 9
        }
    }
}

public struct ClipboardDetectionResult: Sendable {
    public let suggestedTool: ToolCategory
    public let matchedDescription: String
    public let previewSnippet: String

    public init(suggestedTool: ToolCategory, matchedDescription: String, previewSnippet: String) {
        self.suggestedTool = suggestedTool
        self.matchedDescription = matchedDescription
        self.previewSnippet = previewSnippet
    }
}

public struct ClipboardDetector: Sendable {
    public init() {}

    /// On-demand check of clipboard content. Does NOT poll in background.
    public static func detect(content: String) -> ClipboardDetectionResult? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let snippet = String(trimmed.prefix(60))

        // 1. JWT: Starts with eyJ and has 2 periods
        if trimmed.hasPrefix("eyJ") && trimmed.components(separatedBy: ".").count == 3 {
            return ClipboardDetectionResult(
                suggestedTool: .jwt,
                matchedDescription: "检测到 JWT 令牌",
                previewSnippet: snippet
            )
        }

        // 2. JSON: Starts with { or [ and valid JSON
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let data = trimmed.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
                return ClipboardDetectionResult(
                    suggestedTool: .json,
                    matchedDescription: "检测到有效 JSON 数据",
                    previewSnippet: snippet
                )
            }
        }

        // 3. SQL: Starts with or contains SELECT / INSERT / UPDATE / CREATE
        let upper = trimmed.uppercased()
        if upper.hasPrefix("SELECT ") || upper.hasPrefix("INSERT INTO ") || upper.hasPrefix("UPDATE ") || upper.hasPrefix("CREATE TABLE ") {
            return ClipboardDetectionResult(
                suggestedTool: .json,
                matchedDescription: "检测到 SQL 查询语句",
                previewSnippet: snippet
            )
        }

        // 4. XML / HTML: Starts with < and has closing tags
        if trimmed.hasPrefix("<") && (trimmed.contains("</") || trimmed.contains("/>")) {
            return ClipboardDetectionResult(
                suggestedTool: .json,
                matchedDescription: "检测到 XML / HTML 数据",
                previewSnippet: snippet
            )
        }

        // 3. URL encoding: contains %XX
        if trimmed.contains("%") {
            if let regex = try? NSRegularExpression(pattern: "%[0-9A-Fa-f]{2}"),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                return ClipboardDetectionResult(
                    suggestedTool: .url,
                    matchedDescription: "检测到包含 URL 百分比编码",
                    previewSnippet: snippet
                )
            }
        }

        // 4. Timestamp: 10 or 13 digits pure number
        if let _ = Int64(trimmed), (trimmed.count == 10 || trimmed.count == 13) {
            return ClipboardDetectionResult(
                suggestedTool: .timestamp,
                matchedDescription: "检测到 Unix 时间戳数值",
                previewSnippet: snippet
            )
        }

        // 5. Hash: 32 (MD5), 40 (SHA1), 64 (SHA256) hex chars
        if (trimmed.count == 32 || trimmed.count == 40 || trimmed.count == 64) &&
           trimmed.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil {
            return ClipboardDetectionResult(
                suggestedTool: .hash,
                matchedDescription: "检测到哈希校验值",
                previewSnippet: snippet
            )
        }

        // 6. Base64: length > 24, multiple of 4, valid charset
        if trimmed.count >= 24 && trimmed.count % 4 == 0 &&
           trimmed.range(of: "^[A-Za-z0-9+/=]+$", options: .regularExpression) != nil {
            if Data(base64Encoded: trimmed) != nil {
                return ClipboardDetectionResult(
                    suggestedTool: .base64,
                    matchedDescription: "检测到疑似 Base64 编码数据",
                    previewSnippet: snippet
                )
            }
        }

        return nil
    }
}
