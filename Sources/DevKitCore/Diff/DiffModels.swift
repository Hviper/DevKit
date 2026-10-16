import Foundation

public enum DiffChangeType: String, Sendable, Codable {
    case unchanged
    case added
    case deleted
    case modified
}

public struct DiffLine: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let lineNumber: Int?
    public let content: String
    public let type: DiffChangeType

    public init(id: UUID = UUID(), lineNumber: Int?, content: String, type: DiffChangeType) {
        self.id = id
        self.lineNumber = lineNumber
        self.content = content
        self.type = type
    }
}

public struct SideBySideRow: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let leftLine: DiffLine?
    public let rightLine: DiffLine?
    public let type: DiffChangeType

    public init(id: UUID = UUID(), leftLine: DiffLine?, rightLine: DiffLine?, type: DiffChangeType) {
        self.id = id
        self.leftLine = leftLine
        self.rightLine = rightLine
        self.type = type
    }
}

public struct DiffResult: Sendable, Equatable {
    public let sideBySideRows: [SideBySideRow]
    public let unifiedLines: [DiffLine]
    public let additions: Int
    public let deletions: Int
    public let modifications: Int
    public let isIdentical: Bool

    public static let empty = DiffResult(
        sideBySideRows: [],
        unifiedLines: [],
        additions: 0,
        deletions: 0,
        modifications: 0,
        isIdentical: true
    )

    public init(
        sideBySideRows: [SideBySideRow],
        unifiedLines: [DiffLine],
        additions: Int,
        deletions: Int,
        modifications: Int,
        isIdentical: Bool
    ) {
        self.sideBySideRows = sideBySideRows
        self.unifiedLines = unifiedLines
        self.additions = additions
        self.deletions = deletions
        self.modifications = modifications
        self.isIdentical = isIdentical
    }
}
