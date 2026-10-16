import Foundation
import CryptoKit

public enum HashAlgorithm: String, Sendable, CaseIterable, Identifiable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"

    public var id: String { rawValue }
}

public struct HashResult: Sendable, Identifiable {
    public let algorithm: HashAlgorithm
    public let hash: String
    public let isHMAC: Bool

    public var id: String { "\(algorithm.rawValue)_\(isHMAC)" }

    public init(algorithm: HashAlgorithm, hash: String, isHMAC: Bool = false) {
        self.algorithm = algorithm
        self.hash = hash
        self.isHMAC = isHMAC
    }
}

public struct HashGeneratorTool: Sendable {
    public init() {}

    public static func computeHash(
        for data: Data,
        algorithms: [HashAlgorithm] = HashAlgorithm.allCases,
        uppercase: Bool = false
    ) -> [HashResult] {
        return algorithms.map { algo in
            let hashString: String
            switch algo {
            case .md5:
                let digest = Insecure.MD5.hash(data: data)
                hashString = digest.map { String(format: "%02hhx", $0) }.joined()
            case .sha1:
                let digest = Insecure.SHA1.hash(data: data)
                hashString = digest.map { String(format: "%02hhx", $0) }.joined()
            case .sha256:
                let digest = SHA256.hash(data: data)
                hashString = digest.map { String(format: "%02hhx", $0) }.joined()
            case .sha512:
                let digest = SHA512.hash(data: data)
                hashString = digest.map { String(format: "%02hhx", $0) }.joined()
            }

            return HashResult(
                algorithm: algo,
                hash: uppercase ? hashString.uppercased() : hashString.lowercased(),
                isHMAC: false
            )
        }
    }

    public static func computeHash(
        for text: String,
        algorithms: [HashAlgorithm] = HashAlgorithm.allCases,
        uppercase: Bool = false
    ) -> [HashResult] {
        let data = text.data(using: .utf8) ?? Data()
        return computeHash(for: data, algorithms: algorithms, uppercase: uppercase)
    }

    public static func computeHMAC(
        for text: String,
        secretKey: String,
        algorithms: [HashAlgorithm] = HashAlgorithm.allCases,
        uppercase: Bool = false
    ) -> [HashResult] {
        let data = text.data(using: .utf8) ?? Data()
        let key = SymmetricKey(data: secretKey.data(using: .utf8) ?? Data())

        return algorithms.map { algo in
            let hashString: String
            switch algo {
            case .md5:
                let code = HMAC<Insecure.MD5>.authenticationCode(for: data, using: key)
                hashString = code.map { String(format: "%02hhx", $0) }.joined()
            case .sha1:
                let code = HMAC<Insecure.SHA1>.authenticationCode(for: data, using: key)
                hashString = code.map { String(format: "%02hhx", $0) }.joined()
            case .sha256:
                let code = HMAC<SHA256>.authenticationCode(for: data, using: key)
                hashString = code.map { String(format: "%02hhx", $0) }.joined()
            case .sha512:
                let code = HMAC<SHA512>.authenticationCode(for: data, using: key)
                hashString = code.map { String(format: "%02hhx", $0) }.joined()
            }

            return HashResult(
                algorithm: algo,
                hash: uppercase ? hashString.uppercased() : hashString.lowercased(),
                isHMAC: true
            )
        }
    }
}
