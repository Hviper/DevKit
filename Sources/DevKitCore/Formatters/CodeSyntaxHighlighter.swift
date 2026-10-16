import Foundation
import AppKit

public struct CodeSyntaxHighlighter: Sendable {
    public init() {}

    public static func highlight(
        text: String,
        language: CodeLanguage,
        fontSize: CGFloat = 12
    ) -> NSAttributedString {
        guard !text.isEmpty else {
            return NSAttributedString()
        }

        switch language {
        case .json:
            return JSONSyntaxHighlighter.highlight(jsonString: text, fontSize: fontSize)
        case .sql:
            return highlightSQL(text, fontSize: fontSize)
        case .xml:
            return highlightXML(text, fontSize: fontSize)
        case .yaml:
            return highlightYAML(text, fontSize: fontSize)
        case .css:
            return highlightCSS(text, fontSize: fontSize)
        case .markdown:
            return highlightMarkdown(text, fontSize: fontSize)
        case .plain:
            let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let defaultColor = isDarkMode ? NSColor.white : NSColor.black
            return NSAttributedString(string: text, attributes: [
                .font: baseFont,
                .foregroundColor: defaultColor
            ])
        }
    }

    private static var isDarkMode: Bool {
        if let match = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            return match == .darkAqua
        }
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    // MARK: - SQL Highlighting
    private static func highlightSQL(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let isDark = isDarkMode
        let keywordColor = isDark ? NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0) : NSColor(red: 0.05, green: 0.40, blue: 0.85, alpha: 1.0)
        let stringColor = isDark ? NSColor(red: 0.60, green: 0.85, blue: 0.55, alpha: 1.0) : NSColor(red: 0.15, green: 0.60, blue: 0.25, alpha: 1.0)
        let numberColor = isDark ? NSColor(red: 0.85, green: 0.60, blue: 1.0, alpha: 1.0) : NSColor(red: 0.60, green: 0.15, blue: 0.80, alpha: 1.0)
        let commentColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.50, alpha: 1.0)
        let defaultColor = isDark ? NSColor.white : NSColor.black

        let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: defaultColor
        ])

        let sqlKeywords: Set<String> = [
            "SELECT", "FROM", "WHERE", "GROUP", "BY", "HAVING", "ORDER",
            "LIMIT", "OFFSET", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "FULL",
            "CROSS", "ON", "AND", "OR", "AS", "IN", "IS", "NOT", "NULL",
            "LIKE", "BETWEEN", "EXISTS", "UNION", "ALL", "INSERT", "INTO",
            "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "ALTER",
            "DROP", "WITH", "CASE", "WHEN", "THEN", "ELSE", "END", "ASC", "DESC",
            "COUNT", "SUM", "AVG", "MIN", "MAX", "COALESCE", "CONCAT", "DISTINCT",
            "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "DEFAULT", "INDEX", "VIEW"
        ]

        let nsString = text as NSString
        let length = nsString.length

        // Highlight line comments --
        if let commentRegex = try? NSRegularExpression(pattern: "--.*$|/\\*.*?\\*/", options: .anchorsMatchLines) {
            let matches = commentRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: commentColor, range: match.range)
            }
        }

        // Highlight strings
        if let stringRegex = try? NSRegularExpression(pattern: "'([^'\\\\]|\\\\.)*'", options: []) {
            let matches = stringRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: stringColor, range: match.range)
            }
        }

        // Highlight numbers
        if let numberRegex = try? NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?\\b", options: []) {
            let matches = numberRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: numberColor, range: match.range)
            }
        }

        // Highlight keywords
        if let wordRegex = try? NSRegularExpression(pattern: "\\b[A-Za-z_][A-Za-z0-9_]*\\b", options: []) {
            let matches = wordRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                let word = nsString.substring(with: match.range).uppercased()
                if sqlKeywords.contains(word) {
                    result.addAttributes([
                        .foregroundColor: keywordColor,
                        .font: boldFont
                    ], range: match.range)
                }
            }
        }

        return result
    }

    // MARK: - XML / HTML Highlighting
    private static func highlightXML(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let isDark = isDarkMode
        let tagColor = isDark ? NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0) : NSColor(red: 0.05, green: 0.40, blue: 0.85, alpha: 1.0)
        let attrNameColor = isDark ? NSColor(red: 1.0, green: 0.70, blue: 0.40, alpha: 1.0) : NSColor(red: 0.85, green: 0.40, blue: 0.05, alpha: 1.0)
        let attrValueColor = isDark ? NSColor(red: 0.60, green: 0.85, blue: 0.55, alpha: 1.0) : NSColor(red: 0.15, green: 0.60, blue: 0.25, alpha: 1.0)
        let commentColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.50, alpha: 1.0)
        let defaultColor = isDark ? NSColor.white : NSColor.black

        let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: defaultColor
        ])

        let length = (text as NSString).length

        // Comments
        if let commentRegex = try? NSRegularExpression(pattern: "<!--[\\s\\S]*?-->", options: []) {
            let matches = commentRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: commentColor, range: match.range)
            }
        }

        // Tags <... >
        if let tagRegex = try? NSRegularExpression(pattern: "<[/]?[a-zA-Z0-9_\\-:]+", options: []) {
            let matches = tagRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttributes([
                    .foregroundColor: tagColor,
                    .font: boldFont
                ], range: match.range)
            }
        }

        // Attribute names
        if let attrRegex = try? NSRegularExpression(pattern: "\\s+([a-zA-Z0-9_\\-:]+)(?=\\=)", options: []) {
            let matches = attrRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                if match.numberOfRanges > 1 {
                    result.addAttribute(.foregroundColor, value: attrNameColor, range: match.range(at: 1))
                }
            }
        }

        // Attribute values
        if let valRegex = try? NSRegularExpression(pattern: "\"([^\"]*)\"|'([^']*)'", options: []) {
            let matches = valRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: attrValueColor, range: match.range)
            }
        }

        return result
    }

    // MARK: - YAML Highlighting
    private static func highlightYAML(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let isDark = isDarkMode
        let keyColor = isDark ? NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0) : NSColor(red: 0.05, green: 0.40, blue: 0.85, alpha: 1.0)
        let stringColor = isDark ? NSColor(red: 0.60, green: 0.85, blue: 0.55, alpha: 1.0) : NSColor(red: 0.15, green: 0.60, blue: 0.25, alpha: 1.0)
        let numberColor = isDark ? NSColor(red: 0.85, green: 0.60, blue: 1.0, alpha: 1.0) : NSColor(red: 0.60, green: 0.15, blue: 0.80, alpha: 1.0)
        let boolColor = isDark ? NSColor(red: 1.0, green: 0.70, blue: 0.40, alpha: 1.0) : NSColor(red: 0.85, green: 0.40, blue: 0.05, alpha: 1.0)
        let commentColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.50, alpha: 1.0)
        let defaultColor = isDark ? NSColor.white : NSColor.black

        let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: defaultColor
        ])

        let length = (text as NSString).length

        // Comments
        if let commentRegex = try? NSRegularExpression(pattern: "#.*$", options: .anchorsMatchLines) {
            let matches = commentRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: commentColor, range: match.range)
            }
        }

        // Keys: line starting with space then name:
        if let keyRegex = try? NSRegularExpression(pattern: "(^\\s*)(-?\\s*)([a-zA-Z0-9_\\-\\.\\/]+)(?=:)", options: .anchorsMatchLines) {
            let matches = keyRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                if match.numberOfRanges > 3 {
                    result.addAttributes([
                        .foregroundColor: keyColor,
                        .font: boldFont
                    ], range: match.range(at: 3))
                }
            }
        }

        // Strings
        if let stringRegex = try? NSRegularExpression(pattern: "\"([^\"]*)\"|'([^']*)'", options: []) {
            let matches = stringRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: stringColor, range: match.range)
            }
        }

        // Booleans
        if let boolRegex = try? NSRegularExpression(pattern: "\\b(true|false|null|yes|no|on|off)\\b", options: .caseInsensitive) {
            let matches = boolRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: boolColor, range: match.range)
            }
        }

        // Numbers
        if let numberRegex = try? NSRegularExpression(pattern: "(?<=:\\s)[0-9]+(\\.[0-9]+)?", options: []) {
            let matches = numberRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: numberColor, range: match.range)
            }
        }

        return result
    }

    // MARK: - CSS Highlighting
    private static func highlightCSS(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let isDark = isDarkMode
        let selectorColor = isDark ? NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0) : NSColor(red: 0.05, green: 0.40, blue: 0.85, alpha: 1.0)
        let propertyColor = isDark ? NSColor(red: 0.35, green: 0.80, blue: 0.80, alpha: 1.0) : NSColor(red: 0.05, green: 0.55, blue: 0.55, alpha: 1.0)
        let valueColor = isDark ? NSColor(red: 0.60, green: 0.85, blue: 0.55, alpha: 1.0) : NSColor(red: 0.15, green: 0.60, blue: 0.25, alpha: 1.0)
        let unitColor = isDark ? NSColor(red: 0.85, green: 0.60, blue: 1.0, alpha: 1.0) : NSColor(red: 0.60, green: 0.15, blue: 0.80, alpha: 1.0)
        let commentColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.50, alpha: 1.0)
        let defaultColor = isDark ? NSColor.white : NSColor.black

        let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: defaultColor
        ])

        let length = (text as NSString).length

        // Comments
        if let commentRegex = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/", options: []) {
            let matches = commentRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: commentColor, range: match.range)
            }
        }

        // Selectors: anything before {
        if let selRegex = try? NSRegularExpression(pattern: "([^\\{\\}]+)(?=\\{)", options: []) {
            let matches = selRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttributes([
                    .foregroundColor: selectorColor,
                    .font: boldFont
                ], range: match.range)
            }
        }

        // Property names: word before :
        if let propRegex = try? NSRegularExpression(pattern: "([a-zA-Z\\-]+)(?=\\s*:)", options: []) {
            let matches = propRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: propertyColor, range: match.range)
            }
        }

        // Numbers & Units
        if let unitRegex = try? NSRegularExpression(pattern: "\\b[0-9]+(\\.[0-9]+)?(px|rem|em|%|vh|vw|s|ms|pt)?\\b", options: []) {
            let matches = unitRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: unitColor, range: match.range)
            }
        }

        // Strings in CSS
        if let strRegex = try? NSRegularExpression(pattern: "\"([^\"]*)\"|'([^']*)'", options: []) {
            let matches = strRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: valueColor, range: match.range)
            }
        }

        return result
    }

    // MARK: - Markdown Highlighting
    private static func highlightMarkdown(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let isDark = isDarkMode
        let headerColor = isDark ? NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0) : NSColor(red: 0.05, green: 0.40, blue: 0.85, alpha: 1.0)
        let linkColor = isDark ? NSColor(red: 0.35, green: 0.80, blue: 0.80, alpha: 1.0) : NSColor(red: 0.05, green: 0.55, blue: 0.55, alpha: 1.0)
        let codeColor = isDark ? NSColor(red: 1.0, green: 0.70, blue: 0.40, alpha: 1.0) : NSColor(red: 0.85, green: 0.40, blue: 0.05, alpha: 1.0)
        let pipeColor = isDark ? NSColor(white: 0.55, alpha: 1.0) : NSColor(white: 0.50, alpha: 1.0)
        let defaultColor = isDark ? NSColor.white : NSColor.black

        let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: defaultColor
        ])

        let length = (text as NSString).length

        // Headers: ^#{1,6}\s+.*
        if let headerRegex = try? NSRegularExpression(pattern: "^#{1,6}\\s+.*$", options: .anchorsMatchLines) {
            let matches = headerRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttributes([
                    .foregroundColor: headerColor,
                    .font: boldFont
                ], range: match.range)
            }
        }

        // Inline Code `...`
        if let codeRegex = try? NSRegularExpression(pattern: "`[^`]+`", options: []) {
            let matches = codeRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: codeColor, range: match.range)
            }
        }

        // Table pipes |
        if let pipeRegex = try? NSRegularExpression(pattern: "\\|", options: []) {
            let matches = pipeRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: pipeColor, range: match.range)
            }
        }

        // Links [text](url)
        if let linkRegex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", options: []) {
            let matches = linkRegex.matches(in: text, range: NSRange(location: 0, length: length))
            for match in matches {
                result.addAttribute(.foregroundColor, value: linkColor, range: match.range)
            }
        }

        return result
    }
}
