import Foundation

public struct MyersDiff: Sendable {
    public init() {}

    public enum DiffOperation: Equatable {
        case insert(String)
        case delete(String)
        case equal(String)
    }

    /// Asynchronously compute the difference between old and new text using Myers' Algorithm.
    /// Supports Task cancellation, common prefix/suffix pruning, line-hash acceleration, and bounded D limits.
    public func diff(
        oldText: String,
        newText: String,
        ignoreWhitespace: Bool = false,
        ignoreCase: Bool = false
    ) async -> DiffResult {
        if Task.isCancelled { return .empty }

        let areIdentical: Bool
        if ignoreCase {
            areIdentical = oldText.caseInsensitiveCompare(newText) == .orderedSame
        } else {
            areIdentical = oldText == newText
        }

        if areIdentical && !ignoreWhitespace {
            let lines = oldText.components(separatedBy: "\n")
            var rows: [SideBySideRow] = []
            var unified: [DiffLine] = []
            for (idx, line) in lines.enumerated() {
                let diffL = DiffLine(lineNumber: idx + 1, content: line, type: .unchanged)
                let diffR = DiffLine(lineNumber: idx + 1, content: line, type: .unchanged)
                rows.append(SideBySideRow(leftLine: diffL, rightLine: diffR, type: .unchanged))
                unified.append(diffL)
            }
            return DiffResult(
                sideBySideRows: rows,
                unifiedLines: unified,
                additions: 0,
                deletions: 0,
                modifications: 0,
                isIdentical: true
            )
        }

        let oldLines = oldText.isEmpty ? [] : oldText.components(separatedBy: "\n")
        let newLines = newText.isEmpty ? [] : newText.components(separatedBy: "\n")

        let ops = await computeOperations(
            a: oldLines,
            b: newLines,
            ignoreWhitespace: ignoreWhitespace,
            ignoreCase: ignoreCase
        )

        if Task.isCancelled { return .empty }

        return buildResult(operations: ops, oldLines: oldLines, newLines: newLines)
    }

    private func computeOperations(
        a: [String],
        b: [String],
        ignoreWhitespace: Bool,
        ignoreCase: Bool
    ) async -> [DiffOperation] {
        let n = a.count
        let m = b.count

        if n == 0 {
            return b.map { .insert($0) }
        }
        if m == 0 {
            return a.map { .delete($0) }
        }

        func areEqual(_ s1: String, _ s2: String) -> Bool {
            var str1 = s1
            var str2 = s2
            if ignoreWhitespace {
                str1 = str1.trimmingCharacters(in: .whitespacesAndNewlines)
                str2 = str2.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if ignoreCase {
                return str1.caseInsensitiveCompare(str2) == .orderedSame
            }
            return str1 == str2
        }

        // 1. Common Prefix Optimization
        var prefixLen = 0
        while prefixLen < n && prefixLen < m && areEqual(a[prefixLen], b[prefixLen]) {
            prefixLen += 1
        }

        // 2. Common Suffix Optimization
        var suffixLen = 0
        while suffixLen < (n - prefixLen) && suffixLen < (m - prefixLen) &&
              areEqual(a[n - 1 - suffixLen], b[m - 1 - suffixLen]) {
            suffixLen += 1
        }

        var prefixOps: [DiffOperation] = []
        if prefixLen > 0 {
            prefixOps = a[0..<prefixLen].map { .equal($0) }
        }

        var suffixOps: [DiffOperation] = []
        if suffixLen > 0 {
            suffixOps = a[(n - suffixLen)..<n].map { .equal($0) }
        }

        let middleA = Array(a[prefixLen..<(n - suffixLen)])
        let middleB = Array(b[prefixLen..<(m - suffixLen)])

        var middleOps: [DiffOperation] = []
        if middleA.isEmpty {
            middleOps = middleB.map { .insert($0) }
        } else if middleB.isEmpty {
            middleOps = middleA.map { .delete($0) }
        } else {
            middleOps = await computeMiddleMyers(
                a: middleA,
                b: middleB,
                ignoreWhitespace: ignoreWhitespace,
                ignoreCase: ignoreCase
            )
        }

        return prefixOps + middleOps + suffixOps
    }

    private func computeMiddleMyers(
        a: [String],
        b: [String],
        ignoreWhitespace: Bool,
        ignoreCase: Bool
    ) async -> [DiffOperation] {
        let n = a.count
        let m = b.count

        func areEqual(_ s1: String, _ s2: String) -> Bool {
            var str1 = s1
            var str2 = s2
            if ignoreWhitespace {
                str1 = str1.trimmingCharacters(in: .whitespacesAndNewlines)
                str2 = str2.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if ignoreCase {
                return str1.caseInsensitiveCompare(str2) == .orderedSame
            }
            return str1 == str2
        }

        // Precompute line hashes for O(1) equality check
        let aHashes: [Int] = a.map {
            var s = $0
            if ignoreWhitespace { s = s.trimmingCharacters(in: .whitespacesAndNewlines) }
            if ignoreCase { s = s.lowercased() }
            return s.hashValue
        }
        let bHashes: [Int] = b.map {
            var s = $0
            if ignoreWhitespace { s = s.trimmingCharacters(in: .whitespacesAndNewlines) }
            if ignoreCase { s = s.lowercased() }
            return s.hashValue
        }

        let maxD = n + m
        // Bounded Myers: if difference count exceeds limit (e.g. 1500), fall back to chunk replace
        let limitD = min(maxD, 1500)
        let offset = limitD

        // Flat array indexing for cache locality: index = k + offset
        var v = [Int](repeating: -1, count: 2 * limitD + 2)
        v[1 + offset] = 0

        var trace: [[Int]] = []

        var reachedEnd = false
        var finalD = 0

        outer: for d in 0...limitD {
            if Task.isCancelled { return [] }
            trace.append(v)
            finalD = d

            for k in stride(from: -d, through: d, by: 2) {
                let kIdx = k + offset
                var x: Int
                if k == -d || (k != d && v[kIdx - 1] < v[kIdx + 1]) {
                    x = v[kIdx + 1]
                } else {
                    x = v[kIdx - 1] + 1
                }
                var y = x - k

                while x < n && y < m && aHashes[x] == bHashes[y] && areEqual(a[x], b[y]) {
                    x += 1
                    y += 1
                }

                v[kIdx] = x

                if x >= n && y >= m {
                    reachedEnd = true
                    break outer
                }
            }
        }

        // If exceeded limitD without full path (extremely massive disparate files),
        // fallback gracefully: delete old chunk and insert new chunk to guarantee zero freeze
        if !reachedEnd {
            var fallbackOps: [DiffOperation] = []
            fallbackOps.append(contentsOf: a.map { .delete($0) })
            fallbackOps.append(contentsOf: b.map { .insert($0) })
            return fallbackOps
        }

        // Backtrack
        var x = n
        var y = m
        var ops: [DiffOperation] = []

        for d in stride(from: finalD, through: 0, by: -1) {
            let prevV = trace[d]
            let k = x - y
            let kIdx = k + offset

            let prevK: Int
            if k == -d || (k != d && (kIdx - 1 >= 0 ? prevV[kIdx - 1] : -1) < (kIdx + 1 < prevV.count ? prevV[kIdx + 1] : -1)) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }

            let prevKIdx = prevK + offset
            let prevX = (prevKIdx >= 0 && prevKIdx < prevV.count) ? prevV[prevKIdx] : 0
            let prevY = prevX - prevK

            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                ops.append(.equal(a[x]))
            }

            if d > 0 {
                if x == prevX {
                    y -= 1
                    ops.append(.insert(b[y]))
                } else if y == prevY {
                    x -= 1
                    ops.append(.delete(a[x]))
                }
            }
        }

        return ops.reversed()
    }

    private func buildResult(
        operations: [DiffOperation],
        oldLines: [String],
        newLines: [String]
    ) -> DiffResult {
        var sideBySideRows: [SideBySideRow] = []
        var unifiedLines: [DiffLine] = []
        var leftLineNum = 1
        var rightLineNum = 1
        var additions = 0
        var deletions = 0

        var i = 0
        while i < operations.count {
            let op = operations[i]
            switch op {
            case .equal(let line):
                let left = DiffLine(lineNumber: leftLineNum, content: line, type: .unchanged)
                let right = DiffLine(lineNumber: rightLineNum, content: line, type: .unchanged)
                sideBySideRows.append(SideBySideRow(leftLine: left, rightLine: right, type: .unchanged))
                unifiedLines.append(left)
                leftLineNum += 1
                rightLineNum += 1
                i += 1

            case .delete(let delLine):
                // Look ahead for paired insert (modification)
                if i + 1 < operations.count, case .insert(let insLine) = operations[i + 1] {
                    let left = DiffLine(lineNumber: leftLineNum, content: delLine, type: .modified)
                    let right = DiffLine(lineNumber: rightLineNum, content: insLine, type: .modified)
                    sideBySideRows.append(SideBySideRow(leftLine: left, rightLine: right, type: .modified))
                    unifiedLines.append(left)
                    unifiedLines.append(right)
                    leftLineNum += 1
                    rightLineNum += 1
                    deletions += 1
                    additions += 1
                    i += 2
                } else {
                    let left = DiffLine(lineNumber: leftLineNum, content: delLine, type: .deleted)
                    sideBySideRows.append(SideBySideRow(leftLine: left, rightLine: nil, type: .deleted))
                    unifiedLines.append(left)
                    leftLineNum += 1
                    deletions += 1
                    i += 1
                }

            case .insert(let insLine):
                let right = DiffLine(lineNumber: rightLineNum, content: insLine, type: .added)
                sideBySideRows.append(SideBySideRow(leftLine: nil, rightLine: right, type: .added))
                unifiedLines.append(right)
                rightLineNum += 1
                additions += 1
                i += 1
            }
        }

        let isIdentical = additions == 0 && deletions == 0

        return DiffResult(
            sideBySideRows: sideBySideRows,
            unifiedLines: unifiedLines,
            additions: additions,
            deletions: deletions,
            modifications: 0,
            isIdentical: isIdentical
        )
    }
}
