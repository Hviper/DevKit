import Foundation

public struct RegexMatchResult: Sendable, Identifiable {
    public let id: UUID
    public let matchIndex: Int
    public let fullMatch: String
    public let range: NSRange
    public let captureGroups: [String]

    public init(id: UUID = UUID(), matchIndex: Int, fullMatch: String, range: NSRange, captureGroups: [String]) {
        self.id = id
        self.matchIndex = matchIndex
        self.fullMatch = fullMatch
        self.range = range
        self.captureGroups = captureGroups
    }
}

public struct RegexTestOutput: Sendable {
    public let matches: [RegexMatchResult]
    public let totalCount: Int
    public let error: String?
    public let isTimeout: Bool

    public static let empty = RegexTestOutput(matches: [], totalCount: 0, error: nil, isTimeout: false)
}

public struct RegexTesterTool: Sendable {
    public init() {}

    public struct Flags: Sendable {
        public var caseInsensitive: Bool = false
        public var multiline: Bool = false
        public var dotMatchesLineSeparators: Bool = false

        public init(caseInsensitive: Bool = false, multiline: Bool = false, dotMatchesLineSeparators: Bool = false) {
            self.caseInsensitive = caseInsensitive
            self.multiline = multiline
            self.dotMatchesLineSeparators = dotMatchesLineSeparators
        }

        public var nsOptions: NSRegularExpression.Options {
            var opts: NSRegularExpression.Options = []
            if caseInsensitive { opts.insert(.caseInsensitive) }
            if multiline { opts.insert(.anchorsMatchLines) }
            if dotMatchesLineSeparators { opts.insert(.dotMatchesLineSeparators) }
            return opts
        }
    }

    /// Asynchronously test regex against text with 2-second timeout protection against ReDoS
    public static func test(
        pattern: String,
        text: String,
        flags: Flags = Flags()
    ) async -> RegexTestOutput {
        guard !pattern.isEmpty else { return .empty }

        // Compile regex first
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: flags.nsOptions)
        } catch {
            return RegexTestOutput(matches: [], totalCount: 0, error: "语法错误: \(error.localizedDescription)", isTimeout: false)
        }

        // Run matching with timeout
        return await withTaskGroup(of: RegexTestOutput.self) { group in
            // Worker task
            group.addTask {
                let nsText = text as NSString
                let fullRange = NSRange(location: 0, length: nsText.length)
                let textMatches = regex.matches(in: text, options: [], range: fullRange)

                var results: [RegexMatchResult] = []
                for (idx, match) in textMatches.enumerated() {
                    if Task.isCancelled { break }
                    let matchStr = nsText.substring(with: match.range)
                    var groups: [String] = []
                    if match.numberOfRanges > 1 {
                        for g in 1..<match.numberOfRanges {
                            let gRange = match.range(at: g)
                            if gRange.location != NSNotFound {
                                groups.append(nsText.substring(with: gRange))
                            } else {
                                groups.append("")
                            }
                        }
                    }
                    results.append(RegexMatchResult(
                        matchIndex: idx + 1,
                        fullMatch: matchStr,
                        range: match.range,
                        captureGroups: groups
                    ))
                }

                return RegexTestOutput(matches: results, totalCount: results.count, error: nil, isTimeout: false)
            }

            // Timeout watchdog task (2.0s)
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return RegexTestOutput(
                    matches: [],
                    totalCount: 0,
                    error: "⚠️ 正则执行超时（>2s），可能存在灾难性回溯 (ReDoS)，请优化表达式",
                    isTimeout: true
                )
            }

            // First task to finish wins
            if let first = await group.next() {
                group.cancelAll()
                return first
            }
            return .empty
        }
    }
}
