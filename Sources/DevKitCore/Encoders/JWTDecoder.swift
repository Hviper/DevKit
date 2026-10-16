import Foundation

public struct JWTTokenInfo: Sendable {
    public let headerJSON: String
    public let payloadJSON: String
    public let signature: String
    public let isExpired: Bool?
    public let expirationDate: Date?
    public let issuedAtDate: Date?
    public let statusMessage: String

    public init(
        headerJSON: String,
        payloadJSON: String,
        signature: String,
        isExpired: Bool?,
        expirationDate: Date?,
        issuedAtDate: Date?,
        statusMessage: String
    ) {
        self.headerJSON = headerJSON
        self.payloadJSON = payloadJSON
        self.signature = signature
        self.isExpired = isExpired
        self.expirationDate = expirationDate
        self.issuedAtDate = issuedAtDate
        self.statusMessage = statusMessage
    }
}

public struct JWTDecoderTool: Sendable {
    public init() {}

    public static func decode(_ jwtString: String) -> Result<JWTTokenInfo, Error> {
        let parts = jwtString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ".")
        guard parts.count == 3 else {
            return .failure(NSError(domain: "JWTError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效的 JWT 格式（应包含两段点分隔符：header.payload.signature）"]))
        }

        func decodeBase64URL(_ base64Url: String) -> (Data?, String) {
            var b64 = base64Url
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            let padLength = (4 - (b64.count % 4)) % 4
            if padLength > 0 {
                b64 += String(repeating: "=", count: padLength)
            }
            guard let data = Data(base64Encoded: b64) else {
                return (nil, "Base64 解码失败")
            }
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let prettyStr = String(data: prettyData, encoding: .utf8) {
                return (data, prettyStr)
            }
            return (data, String(data: data, encoding: .utf8) ?? "{}")
        }

        let (_, headerStr) = decodeBase64URL(parts[0])
        let (payloadData, payloadStr) = decodeBase64URL(parts[1])
        let signature = parts[2]

        var isExpired: Bool? = nil
        var expirationDate: Date? = nil
        var issuedAtDate: Date? = nil
        var status = "Token 格式解析成功（未签名校验，需私钥验证有效性）"

        if let pData = payloadData,
           let json = (try? JSONSerialization.jsonObject(with: pData)) as? [String: Any] {
            if let exp = json["exp"] as? TimeInterval {
                let expDate = Date(timeIntervalSince1970: exp)
                expirationDate = expDate
                let now = Date()
                if expDate < now {
                    isExpired = true
                    status = "❌ Token 已过期 (过期时间: \(expDate.formatted()))"
                } else {
                    isExpired = false
                    status = "✅ Token 处于有效期内 (有效期至: \(expDate.formatted()))"
                }
            }
            if let iat = json["iat"] as? TimeInterval {
                issuedAtDate = Date(timeIntervalSince1970: iat)
            }
        }

        return .success(JWTTokenInfo(
            headerJSON: headerStr,
            payloadJSON: payloadStr,
            signature: signature,
            isExpired: isExpired,
            expirationDate: expirationDate,
            issuedAtDate: issuedAtDate,
            statusMessage: status
        ))
    }
}
