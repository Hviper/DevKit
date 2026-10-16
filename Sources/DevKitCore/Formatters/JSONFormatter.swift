import Foundation

public struct JSONFormatterTool: Sendable {
    public init() {}

    public enum IndentStyle: String, Sendable, CaseIterable {
        case twoSpaces = "2 个空格"
        case fourSpaces = "4 个空格"
        case tabs = "Tab 制表符"

        public var indentString: String {
            switch self {
            case .twoSpaces: return "  "
            case .fourSpaces: return "    "
            case .tabs: return "\t"
            }
        }
    }

    public enum FormatMode: String, Sendable, CaseIterable {
        case pretty = "美化格式"
        case minify = "压缩单行"
        case validate = "仅语法校验"
    }

    public enum ModelLanguage: String, Sendable, CaseIterable, Identifiable {
        case typeScript = "TypeScript Interface"
        case swift = "Swift Codable Struct"

        public var id: String { rawValue }
    }

    public static func format(
        _ jsonString: String,
        mode: FormatMode = .pretty,
        indent: IndentStyle = .twoSpaces,
        sortKeys: Bool = true
    ) -> Result<String, DevKitError> {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success("")
        }

        guard let data = trimmed.data(using: .utf8) else {
            return .failure(DevKitError("无法以 UTF-8 编码读取输入数据"))
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])

            switch mode {
            case .validate:
                return .success("✅ JSON 语法验证通过！")

            case .minify:
                let minData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.fragmentsAllowed, .sortedKeys])
                if let minStr = String(data: minData, encoding: .utf8) {
                    return .success(minStr)
                }
                return .failure(DevKitError("序列化压缩 JSON 失败"))

            case .pretty:
                var writingOptions: JSONSerialization.WritingOptions = [.prettyPrinted, .fragmentsAllowed]
                if sortKeys {
                    writingOptions.insert(.sortedKeys)
                }
                let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: writingOptions)
                guard var prettyStr = String(data: prettyData, encoding: .utf8) else {
                    return .failure(DevKitError("生成美化 JSON 失败"))
                }

                if indent != .fourSpaces {
                    if indent == .tabs {
                        prettyStr = replaceLeadingSpacesWithTabs(prettyStr)
                    }
                }
                return .success(prettyStr)
            }
        } catch {
            return .failure(DevKitError(describeJSONError(error, rawText: trimmed)))
        }
    }

    /// Evaluate simplified JSONPath / KeyPath query on JSON string
    public static func evaluatePath(_ jsonString: String, path: String) -> Result<String, DevKitError> {
        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "$."))
        guard !cleanPath.isEmpty else {
            return format(jsonString)
        }

        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return .failure(DevKitError("JSON 无效，无法执行路径查询"))
        }

        let parts = cleanPath.components(separatedBy: ".").filter { !$0.isEmpty }
        var current: Any? = obj

        for part in parts {
            if current == nil { break }
            if part.contains("[") && part.contains("]") {
                let key = part.components(separatedBy: "[").first ?? ""
                let idxStr = part.components(separatedBy: "[").last?.replacingOccurrences(of: "]", with: "") ?? ""
                if !key.isEmpty, let dict = current as? [String: Any] {
                    current = dict[key]
                }
                if idxStr == "*" {
                    // wildcard array
                } else if let idx = Int(idxStr), let arr = current as? [Any], idx >= 0, idx < arr.count {
                    current = arr[idx]
                }
            } else if let dict = current as? [String: Any] {
                current = dict[part]
            } else if let arr = current as? [Any] {
                current = arr.compactMap { ($0 as? [String: Any])?[part] }
            } else {
                current = nil
            }
        }

        guard let finalObj = current else {
            return .failure(DevKitError("路径 '\(path)' 未匹配到任何数据"))
        }

        if let validData = try? JSONSerialization.data(withJSONObject: finalObj, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
           let resultStr = String(data: validData, encoding: .utf8) {
            return .success(resultStr)
        } else {
            return .success("\(finalObj)")
        }
    }

    /// Generate TypeScript interface or Swift Codable struct from JSON string
    public static func generateModel(from jsonString: String, language: ModelLanguage, rootName: String = "Root") -> Result<String, DevKitError> {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return .failure(DevKitError("无法解析 JSON，生成模型前请确保语法正确"))
        }

        var models: [String] = []

        if language == .typeScript {
            generateTS(obj: obj, name: rootName, accumulator: &models)
            return .success(models.reversed().joined(separator: "\n\n"))
        } else {
            generateSwift(obj: obj, name: rootName, accumulator: &models)
            let header = "//\n// Generated by DevKit\n//\nimport Foundation\n\n"
            return .success(header + models.reversed().joined(separator: "\n\n"))
        }
    }

    private static func generateTS(obj: Any, name: String, accumulator: inout [String]) {
        if let dict = obj as? [String: Any] {
            var fields: [String] = []
            for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                let tsType = inferTSType(val: val, keyName: key, accumulator: &accumulator)
                fields.append("  \(key): \(tsType);")
            }
            accumulator.append("export interface \(capitalize(name)) {\n\(fields.joined(separator: "\n"))\n}")
        } else if let arr = obj as? [Any], let first = arr.first {
            generateTS(obj: first, name: name + "Item", accumulator: &accumulator)
        }
    }

    private static func inferTSType(val: Any, keyName: String, accumulator: inout [String]) -> String {
        switch val {
        case is String: return "string"
        case is NSNumber:
            if let num = val as? NSNumber {
                return (CFNumberGetType(num as CFNumber) == .charType) ? "boolean" : "number"
            }
            return "number"
        case is Bool: return "boolean"
        case let dict as [String: Any]:
            let subName = capitalize(keyName)
            generateTS(obj: dict, name: subName, accumulator: &accumulator)
            return subName
        case let arr as [Any]:
            if let first = arr.first {
                let subType = inferTSType(val: first, keyName: keyName + "Item", accumulator: &accumulator)
                return "\(subType)[]"
            }
            return "any[]"
        default:
            return "any"
        }
    }

    private static func generateSwift(obj: Any, name: String, accumulator: inout [String]) {
        if let dict = obj as? [String: Any] {
            var fields: [String] = []
            for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                let swiftType = inferSwiftType(val: val, keyName: key, accumulator: &accumulator)
                let safeKey = sanitizeSwiftKey(key)
                if safeKey != key {
                    fields.append("    let \(safeKey): \(swiftType) // key: \"\(key)\"")
                } else {
                    fields.append("    let \(key): \(swiftType)")
                }
            }
            accumulator.append("struct \(capitalize(name)): Codable {\n\(fields.joined(separator: "\n"))\n}")
        } else if let arr = obj as? [Any], let first = arr.first {
            generateSwift(obj: first, name: name + "Item", accumulator: &accumulator)
        }
    }

    private static func inferSwiftType(val: Any, keyName: String, accumulator: inout [String]) -> String {
        switch val {
        case is String: return "String"
        case is NSNumber:
            if let num = val as? NSNumber {
                if CFNumberGetType(num as CFNumber) == .charType { return "Bool" }
                if num.stringValue.contains(".") { return "Double" }
                return "Int"
            }
            return "Int"
        case is Bool: return "Bool"
        case let dict as [String: Any]:
            let subName = capitalize(keyName)
            generateSwift(obj: dict, name: subName, accumulator: &accumulator)
            return subName
        case let arr as [Any]:
            if let first = arr.first {
                let subType = inferSwiftType(val: first, keyName: keyName + "Item", accumulator: &accumulator)
                return "[\(subType)]"
            }
            return "[String]"
        default:
            return "String"
        }
    }

    private static func capitalize(_ str: String) -> String {
        guard let first = str.first else { return "Model" }
        return String(first).uppercased() + String(str.dropFirst())
    }

    private static func sanitizeSwiftKey(_ key: String) -> String {
        let reserved = ["default", "switch", "case", "let", "var", "for", "in", "repeat", "while", "return", "class", "struct", "enum", "extension", "import", "typealias"]
        if reserved.contains(key) {
            return "`\(key)`"
        }
        return key
    }

    /// Attempt to sanitize single quotes and trailing commas
    public static func tryRepairJSON(_ text: String) -> String {
        var repaired = text
        repaired = repaired.replacingOccurrences(
            of: "'([^'\\r\\n]+)'(?=\\s*:)",
            with: "\"$1\"",
            options: .regularExpression
        )
        repaired = repaired.replacingOccurrences(
            of: "(?<=:\\s*)'([^'\\r\\n]*)'",
            with: "\"$1\"",
            options: .regularExpression
        )
        repaired = repaired.replacingOccurrences(
            of: ",(\\s*[}\\]])",
            with: "$1",
            options: .regularExpression
        )
        return repaired
    }

    private static func describeJSONError(_ error: Error, rawText: String) -> String {
        let nsError = error as NSError
        if let desc = nsError.userInfo["NSDebugDescription"] as? String {
            return "语法错误: \(desc)"
        }
        return "JSON 解析失败: \(error.localizedDescription)"
    }

    private static func replaceLeadingSpacesWithTabs(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let tabbed = lines.map { line -> String in
            var spaceCount = 0
            for ch in line {
                if ch == " " { spaceCount += 1 } else { break }
            }
            if spaceCount > 0 {
                let tabs = String(repeating: "\t", count: spaceCount / 2)
                let remainder = String(repeating: " ", count: spaceCount % 2)
                let content = line.dropFirst(spaceCount)
                return tabs + remainder + content
            }
            return line
        }
        return tabbed.joined(separator: "\n")
    }
}
