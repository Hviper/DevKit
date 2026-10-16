import Foundation

public struct URLQueryItemInfo: Sendable, Identifiable {
    public let id = UUID()
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public struct URLEncoderTool: Sendable {
    public init() {}

    public enum EncodeMode: String, Sendable, CaseIterable {
        case component = "组件编码 (Component)"
        case full = "完整编码 (Full URL)"
    }

    public static func encode(_ text: String, mode: EncodeMode = .component) -> String {
        switch mode {
        case .component:
            return text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        case .full:
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
        }
    }

    public static func decode(_ text: String) -> (result: String, warning: String?) {
        guard let decoded = text.removingPercentEncoding else {
            return (text, "存在无法解码的字符序列")
        }

        var warning: String? = nil
        if decoded.contains("%") && (try? NSRegularExpression(pattern: "%[0-9A-Fa-f]{2}").firstMatch(in: decoded, range: NSRange(decoded.startIndex..., in: decoded))) != nil {
            warning = "检测到可能包含多重 URL 编码，可再次解码"
        }

        return (decoded, warning)
    }

    public static func parseQueryParams(_ urlString: String) -> [URLQueryItemInfo] {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let components = URLComponents(string: trimmed), let items = components.queryItems, !items.isEmpty {
            return items.map { URLQueryItemInfo(name: $0.name, value: $0.value ?? "") }
        }
        // Try decoding first if it was fully percent-encoded
        if let decoded = trimmed.removingPercentEncoding,
           let components = URLComponents(string: decoded),
           let items = components.queryItems, !items.isEmpty {
            return items.map { URLQueryItemInfo(name: $0.name, value: $0.value ?? "") }
        }
        return []
    }
}
