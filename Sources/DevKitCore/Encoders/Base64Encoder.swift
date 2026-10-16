import Foundation

public struct Base64EncoderTool: Sendable {
    public init() {}

    public static func encodeText(_ text: String, urlSafe: Bool = false) -> String {
        guard let data = text.data(using: .utf8) else { return "" }
        var result = data.base64EncodedString()
        if urlSafe {
            result = result
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        }
        return result
    }

    public static func decodeText(_ base64: String) -> Result<String, Error> {
        var sanitized = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        // Convert url-safe back to standard base64 if needed
        sanitized = sanitized
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Re-pad if necessary
        let padLength = (4 - (sanitized.count % 4)) % 4
        if padLength > 0 {
            sanitized += String(repeating: "=", count: padLength)
        }

        guard let data = Data(base64Encoded: sanitized) else {
            return .failure(NSError(domain: "Base64Error", code: 1, userInfo: [NSLocalizedDescriptionKey: "非法的 Base64 编码字符串"]))
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(NSError(domain: "Base64Error", code: 2, userInfo: [NSLocalizedDescriptionKey: "解码成功，但数据非 UTF-8 纯文本（可能为二进制数据）"]))
        }

        return .success(text)
    }

    public static func encodeData(_ data: Data, mimeType: String = "image/png") -> String {
        let b64 = data.base64EncodedString()
        return "data:\(mimeType);base64,\(b64)"
    }
}
