import Foundation

public enum CodeLanguage: String, Sendable, CaseIterable, Identifiable {
    case json = "JSON"
    case sql = "SQL"
    case xml = "XML / HTML"
    case yaml = "YAML"
    case css = "CSS"
    case markdown = "Markdown"
    case plain = "Plain Text"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .json: return "curlybraces"
        case .sql: return "cylinder.split.1x2"
        case .xml: return "chevron.left.forwardslash.chevron.right"
        case .yaml: return "doc.text"
        case .css: return "paintbrush"
        case .markdown: return "text.quote"
        case .plain: return "doc.plaintext"
        }
    }
}

public struct SQLFormatOptions: Sendable {
    public enum KeywordCase: String, Sendable, CaseIterable {
        case uppercase = "大写"
        case lowercase = "小写"
        case preserve = "保持原样"
    }

    public enum CommaPosition: String, Sendable, CaseIterable {
        case trailing = "行尾逗号"
        case leading = "行首逗号"
    }

    public var keywordCase: KeywordCase
    public var commaPosition: CommaPosition
    public var indent: String

    public init(
        keywordCase: KeywordCase = .uppercase,
        commaPosition: CommaPosition = .trailing,
        indent: String = "  "
    ) {
        self.keywordCase = keywordCase
        self.commaPosition = commaPosition
        self.indent = indent
    }
}

public struct CodeFormatterTool: Sendable {
    public init() {}

    // MARK: - Auto-detect Language
    public static func detectLanguage(from text: String) -> CodeLanguage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .json }

        // 1. XML / HTML check
        if trimmed.hasPrefix("<") && (trimmed.contains("</") || trimmed.contains("/>") || trimmed.lowercased().hasPrefix("<!doctype") || trimmed.lowercased().hasPrefix("<?xml")) {
            return .xml
        }

        // 2. JSON check
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            return .json
        }

        // 3. SQL check
        let upper = trimmed.uppercased()
        let sqlKeywords = ["SELECT ", "INSERT INTO ", "UPDATE ", "DELETE FROM ", "CREATE TABLE ", "ALTER TABLE ", "DROP TABLE ", "WITH ", "EXPLAIN "]
        for kw in sqlKeywords {
            if upper.contains(kw) {
                return .sql
            }
        }

        // 4. CSS check
        if trimmed.contains("{") && trimmed.contains("}") && (trimmed.contains("px") || trimmed.contains("rem") || trimmed.contains("color:") || trimmed.contains("background:")) {
            return .css
        }

        // 5. YAML check
        if trimmed.hasPrefix("---") || (trimmed.contains(":\n") || (trimmed.contains(": ") && trimmed.contains("\n- "))) {
            return .yaml
        }

        // 6. Markdown check
        if trimmed.contains("# ") || trimmed.contains("## ") || (trimmed.contains("|") && trimmed.contains("---")) {
            return .markdown
        }

        return .json
    }

    // MARK: - SQL Formatter
    public static func formatSQL(
        _ sql: String,
        options: SQLFormatOptions = SQLFormatOptions()
    ) -> String {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let majorKeywords: Set<String> = [
            "SELECT", "FROM", "WHERE", "GROUP BY", "HAVING", "ORDER BY",
            "LIMIT", "OFFSET", "UNION", "UNION ALL", "INSERT INTO", "VALUES",
            "UPDATE", "SET", "DELETE FROM", "CREATE TABLE", "ALTER TABLE",
            "DROP TABLE", "WITH"
        ]

        let secondaryKeywords: Set<String> = [
            "LEFT JOIN", "RIGHT JOIN", "INNER JOIN", "OUTER JOIN", "FULL JOIN",
            "CROSS JOIN", "JOIN", "ON", "AND", "OR"
        ]

        let allReservedKeywords: [String] = [
            "SELECT", "FROM", "WHERE", "GROUP BY", "HAVING", "ORDER BY",
            "LIMIT", "OFFSET", "UNION ALL", "UNION", "INSERT INTO", "VALUES",
            "UPDATE", "SET", "DELETE FROM", "CREATE TABLE", "ALTER TABLE",
            "DROP TABLE", "WITH", "LEFT JOIN", "RIGHT JOIN", "INNER JOIN",
            "OUTER JOIN", "FULL JOIN", "CROSS JOIN", "JOIN", "ON", "AND",
            "OR", "AS", "IN", "IS", "NOT", "NULL", "LIKE", "BETWEEN",
            "EXISTS", "COUNT", "SUM", "AVG", "MIN", "MAX", "DISTINCT",
            "CASE", "WHEN", "THEN", "ELSE", "END", "ASC", "DESC", "BY"
        ]

        // Tokenize while respecting quotes and comments
        var tokens: [String] = []
        var currentToken = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var inBacktick = false

        let chars = Array(trimmed)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if c == "'" && !inDoubleQuote && !inBacktick {
                inSingleQuote.toggle()
                currentToken.append(c)
                i += 1
                continue
            } else if c == "\"" && !inSingleQuote && !inBacktick {
                inDoubleQuote.toggle()
                currentToken.append(c)
                i += 1
                continue
            } else if c == "`" && !inSingleQuote && !inDoubleQuote {
                inBacktick.toggle()
                currentToken.append(c)
                i += 1
                continue
            }

            if inSingleQuote || inDoubleQuote || inBacktick {
                currentToken.append(c)
                i += 1
                continue
            }

            if c == "," || c == ";" || c == "(" || c == ")" {
                if !currentToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    tokens.append(currentToken.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentToken = ""
                }
                tokens.append(String(c))
                i += 1
                continue
            }

            if c.isWhitespace {
                if !currentToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    tokens.append(currentToken.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentToken = ""
                }
                i += 1
                continue
            }

            currentToken.append(c)
            i += 1
        }

        if !currentToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tokens.append(currentToken.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Combine multi-word keywords (e.g. GROUP + BY -> GROUP BY)
        var combinedTokens: [String] = []
        var tIdx = 0
        while tIdx < tokens.count {
            let t = tokens[tIdx]
            if tIdx + 1 < tokens.count {
                let pair = (t + " " + tokens[tIdx + 1]).uppercased()
                if majorKeywords.contains(pair) || secondaryKeywords.contains(pair) {
                    combinedTokens.append(pair)
                    tIdx += 2
                    continue
                }
            }
            combinedTokens.append(t)
            tIdx += 1
        }

        // Build formatted string
        var output = ""
        var indentLevel = 0
        var isAfterMajorKeyword = false

        func appendIndent() {
            output += String(repeating: options.indent, count: max(0, indentLevel))
        }

        for (idx, token) in combinedTokens.enumerated() {
            let upper = token.uppercased()

            // Standardize case
            let displayToken: String
            if allReservedKeywords.contains(upper) {
                switch options.keywordCase {
                case .uppercase: displayToken = upper
                case .lowercase: displayToken = upper.lowercased()
                case .preserve: displayToken = token
                }
            } else {
                displayToken = token
            }

            if majorKeywords.contains(upper) {
                if idx > 0 {
                    output = output.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
                }
                appendIndent()
                output += displayToken + " "
                isAfterMajorKeyword = true
            } else if secondaryKeywords.contains(upper) {
                output = output.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
                output += String(repeating: options.indent, count: max(0, indentLevel + 1))
                output += displayToken + " "
                isAfterMajorKeyword = false
            } else if token == "," {
                if indentLevel == 0 {
                    if options.commaPosition == .trailing {
                        output = output.trimmingCharacters(in: .whitespaces) + ",\n"
                        appendIndent()
                        if isAfterMajorKeyword {
                            output += options.indent
                        }
                    } else {
                        output = output.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
                        appendIndent()
                        output += ", "
                    }
                } else {
                    output = output.trimmingCharacters(in: .whitespaces) + ", "
                }
            } else if token == "(" {
                output = output.trimmingCharacters(in: .whitespaces) + "("
                indentLevel += 1
            } else if token == ")" {
                indentLevel = max(0, indentLevel - 1)
                output = output.trimmingCharacters(in: .whitespaces) + ") "
            } else if token == ";" {
                output = output.trimmingCharacters(in: .whitespaces) + ";\n"
            } else {
                output += displayToken + " "
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func minifySQL(_ sql: String) -> String {
        return sql
            .replacingOccurrences(of: "--.*(\n|$)", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "/\\*.*?\\*/", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - XML / HTML Formatter
    public static func formatXML(_ xml: String, indent: String = "  ") -> String {
        let trimmed = xml.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var output = ""
        var indentLevel = 0

        // Void tags in HTML
        let voidTags: Set<String> = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"]

        var i = 0
        let chars = Array(trimmed)

        while i < chars.count {
            if chars[i] == "<" {
                // Find end of tag
                var tag = "<"
                i += 1
                var inQuote: Character? = nil
                while i < chars.count {
                    let c = chars[i]
                    tag.append(c)
                    if c == "\"" || c == "'" {
                        if inQuote == c { inQuote = nil }
                        else if inQuote == nil { inQuote = c }
                    }
                    if c == ">" && inQuote == nil {
                        i += 1
                        break
                    }
                    i += 1
                }

                let tagContent = tag.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)

                if tag.hasPrefix("</") {
                    // Closing tag
                    indentLevel = max(0, indentLevel - 1)
                    output += "\n" + String(repeating: indent, count: indentLevel) + tag
                } else if tag.hasSuffix("/>") || tag.hasPrefix("<?") || tag.hasPrefix("<!") {
                    // Self-closing or declaration
                    output += "\n" + String(repeating: indent, count: indentLevel) + tag
                } else {
                    // Check if void HTML tag
                    let tagName = tagContent.components(separatedBy: CharacterSet.whitespaces).first?.lowercased() ?? ""
                    let isVoid = voidTags.contains(tagName)

                    output += "\n" + String(repeating: indent, count: indentLevel) + tag
                    if !isVoid {
                        indentLevel += 1
                    }
                }
            } else {
                // Text node
                var text = ""
                while i < chars.count && chars[i] != "<" {
                    text.append(chars[i])
                    i += 1
                }
                let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanText.isEmpty {
                    output += "\n" + String(repeating: indent, count: indentLevel) + cleanText
                }
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func minifyXML(_ xml: String) -> String {
        return xml
            .replacingOccurrences(of: "<!--.*?-->", with: "", options: .regularExpression)
            .replacingOccurrences(of: ">\\s+<", with: "><", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - YAML Formatter & YAML ⇄ JSON Conversion
    public static func jsonToYAML(_ jsonString: String) -> Result<String, DevKitError> {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return .failure(DevKitError("JSON 无效，无法转换为 YAML"))
        }

        var lines: [String] = ["# Generated YAML"]
        serializeYAML(obj: obj, indentLevel: 0, accumulator: &lines)
        return .success(lines.joined(separator: "\n"))
    }

    public static func yamlToJSON(_ yamlString: String) -> Result<String, DevKitError> {
        let rawLines = yamlString.components(separatedBy: "\n")
        var cleanLines: [(indent: Int, text: String)] = []
        for line in rawLines {
            let withoutComment = line.components(separatedBy: "#").first ?? ""
            let trimmed = withoutComment.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == "---" { continue }
            let indent = line.prefix(while: { $0 == " " }).count
            cleanLines.append((indent: indent, text: trimmed))
        }

        guard !cleanLines.isEmpty else {
            return .success("{}")
        }

        var idx = 0

        func parseScalar(_ text: String) -> Any {
            let t = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if text == "true" || text == "True" || text == "yes" { return true }
            if text == "false" || text == "False" || text == "no" { return false }
            if text == "null" || text == "~" { return NSNull() }
            if let intVal = Int(text) { return intVal }
            if let dblVal = Double(text) { return dblVal }
            return t
        }

        func parseValue(at index: inout Int, parentIndent: Int) -> Any {
            if index >= cleanLines.count { return NSNull() }

            if cleanLines[index].text.hasPrefix("- ") {
                var arr: [Any] = []
                let curIndent = cleanLines[index].indent
                while index < cleanLines.count && cleanLines[index].indent == curIndent && cleanLines[index].text.hasPrefix("- ") {
                    let itemText = String(cleanLines[index].text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    index += 1
                    if itemText.isEmpty {
                        arr.append(parseValue(at: &index, parentIndent: curIndent + 2))
                    } else if itemText.contains(":") {
                        var map: [String: Any] = [:]
                        let parts = itemText.split(separator: ":", maxSplits: 1).map(String.init)
                        let k = parts[0].trimmingCharacters(in: .whitespaces)
                        let v = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                        if v.isEmpty {
                            map[k] = parseValue(at: &index, parentIndent: curIndent + 2)
                        } else {
                            map[k] = parseScalar(v)
                        }
                        while index < cleanLines.count && cleanLines[index].indent > curIndent && !cleanLines[index].text.hasPrefix("- ") {
                            let l = cleanLines[index].text
                            if let colonIdx = l.firstIndex(of: ":") {
                                let subK = String(l[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                                let subV = String(l[l.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                                index += 1
                                if subV.isEmpty {
                                    map[subK] = parseValue(at: &index, parentIndent: cleanLines[index - 1].indent + 2)
                                } else {
                                    map[subK] = parseScalar(subV)
                                }
                            } else {
                                index += 1
                            }
                        }
                        arr.append(map)
                    } else {
                        arr.append(parseScalar(itemText))
                    }
                }
                return arr
            } else {
                var dict: [String: Any] = [:]
                let curIndent = cleanLines[index].indent
                while index < cleanLines.count && cleanLines[index].indent >= curIndent {
                    if cleanLines[index].indent < curIndent { break }
                    let line = cleanLines[index].text
                    guard let colonIdx = line.firstIndex(of: ":") else {
                        index += 1
                        continue
                    }
                    let key = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    let valPart = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    index += 1
                    if valPart.isEmpty {
                        if index < cleanLines.count && cleanLines[index].indent > curIndent {
                            dict[key] = parseValue(at: &index, parentIndent: cleanLines[index].indent)
                        } else {
                            dict[key] = NSNull()
                        }
                    } else {
                        dict[key] = parseScalar(valPart)
                    }
                }
                return dict
            }
        }

        let parsed = parseValue(at: &idx, parentIndent: 0)
        guard JSONSerialization.isValidJSONObject(parsed),
              let jsonData = try? JSONSerialization.data(withJSONObject: parsed, options: [.prettyPrinted, .sortedKeys]),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return .failure(DevKitError("YAML 解析失败，请检查格式"))
        }

        return .success(jsonStr)
    }

    private static func serializeYAML(obj: Any, indentLevel: Int, accumulator: inout [String]) {
        let indent = String(repeating: "  ", count: indentLevel)

        if let dict = obj as? [String: Any] {
            for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                if let subDict = val as? [String: Any] {
                    accumulator.append("\(indent)\(key):")
                    serializeYAML(obj: subDict, indentLevel: indentLevel + 1, accumulator: &accumulator)
                } else if let subArr = val as? [Any] {
                    accumulator.append("\(indent)\(key):")
                    serializeYAML(obj: subArr, indentLevel: indentLevel + 1, accumulator: &accumulator)
                } else {
                    accumulator.append("\(indent)\(key): \(formatYAMLValue(val))")
                }
            }
        } else if let arr = obj as? [Any] {
            for item in arr {
                if let subDict = item as? [String: Any] {
                    accumulator.append("\(indent)-")
                    serializeYAML(obj: subDict, indentLevel: indentLevel + 1, accumulator: &accumulator)
                } else {
                    accumulator.append("\(indent)- \(formatYAMLValue(item))")
                }
            }
        } else {
            accumulator.append("\(indent)\(formatYAMLValue(obj))")
        }
    }

    private static func formatYAMLValue(_ val: Any) -> String {
        if let str = val as? String {
            if str.contains("\n") || str.contains(":") || str.contains("#") {
                return "\"\(str.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return str
        } else if let bool = val as? Bool {
            return bool ? "true" : "false"
        } else if let num = val as? NSNumber {
            return "\(num)"
        }
        return "\(val)"
    }

    // MARK: - CSS Formatter
    public static func formatCSS(_ css: String, indent: String = "  ") -> String {
        let clean = css
            .replacingOccurrences(of: "/\\*.*?\\*/", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        var output = ""
        var indentLevel = 0

        for char in clean {
            if char == "{" {
                output = output.trimmingCharacters(in: .whitespaces) + " {\n"
                indentLevel += 1
                output += String(repeating: indent, count: indentLevel)
            } else if char == "}" {
                indentLevel = max(0, indentLevel - 1)
                output = output.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
                output += String(repeating: indent, count: indentLevel) + "}\n\n"
            } else if char == ";" {
                output += ";\n" + String(repeating: indent, count: indentLevel)
            } else if char == ":" {
                output += ": "
            } else {
                output.append(char)
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func minifyCSS(_ css: String) -> String {
        return css
            .replacingOccurrences(of: "/\\*.*?\\*/", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s*([{}:;,])\\s*", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Markdown Formatter (Pangu Spacing + GFM Table Alignment)
    public static func formatMarkdown(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var formattedLines: [String] = []

        var inTable = false
        var tableBuffer: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                inTable = true
                tableBuffer.append(line)
            } else {
                if inTable {
                    formattedLines.append(contentsOf: formatMarkdownTable(tableBuffer))
                    tableBuffer.removeAll()
                    inTable = false
                }
                formattedLines.append(panguSpacing(line))
            }
        }

        if inTable {
            formattedLines.append(contentsOf: formatMarkdownTable(tableBuffer))
        }

        return formattedLines.joined(separator: "\n")
    }

    /// Automatically insert spaces between CJK and ASCII alphanumeric characters
    public static func panguSpacing(_ text: String) -> String {
        var result = text
        // CJK + Latin
        result = result.replacingOccurrences(
            of: "([\\p{Han}])([A-Za-z0-9])",
            with: "$1 $2",
            options: .regularExpression
        )
        // Latin + CJK
        result = result.replacingOccurrences(
            of: "([A-Za-z0-9])([\\p{Han}])",
            with: "$1 $2",
            options: .regularExpression
        )
        return result
    }

    /// Align GFM table columns according to max width
    public static func formatMarkdownTable(_ rows: [String]) -> [String] {
        guard !rows.isEmpty else { return [] }

        // Split each row into cells
        let parsedRows: [[String]] = rows.map { row in
            let inner = row.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            return inner.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        let colCount = parsedRows.map { $0.count }.max() ?? 0
        guard colCount > 0 else { return rows }

        var colWidths = [Int](repeating: 3, count: colCount)

        for row in parsedRows {
            for (cIdx, cell) in row.enumerated() {
                // Calculate display width (CJK = 2, ASCII = 1)
                let w = cell.reduce(0) { $0 + ($1.isASCII ? 1 : 2) }
                colWidths[cIdx] = max(colWidths[cIdx], w)
            }
        }

        var outputRows: [String] = []

        for (rIdx, row) in parsedRows.enumerated() {
            var alignedCells: [String] = []
            let isSeparator = rIdx == 1 && row.allSatisfy { $0.contains("-") }

            for cIdx in 0..<colCount {
                let cell = (cIdx < row.count) ? row[cIdx] : ""
                let targetW = colWidths[cIdx]

                if isSeparator {
                    let dashes = String(repeating: "-", count: max(3, targetW))
                    alignedCells.append(dashes)
                } else {
                    let currentW = cell.reduce(0) { $0 + ($1.isASCII ? 1 : 2) }
                    let padding = max(0, targetW - currentW)
                    alignedCells.append(cell + String(repeating: " ", count: padding))
                }
            }

            outputRows.append("| " + alignedCells.joined(separator: " | ") + " |")
        }

        return outputRows
    }
}
