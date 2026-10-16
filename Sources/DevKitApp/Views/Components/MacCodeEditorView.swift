import SwiftUI
import AppKit
import DevKitCore

public struct MacCodeEditorView: NSViewRepresentable {
    @Binding var text: String
    let isEditable: Bool
    let language: CodeLanguage
    let fontSize: CGFloat
    let showLineNumbers: Bool
    let indentString: String
    let searchQuery: String
    let currentMatchIndex: Int
    let isCaseSensitive: Bool
    let onFormatAction: (() -> Void)?
    let onMatchCountChanged: ((Int) -> Void)?

    // Initializer for two-way editable mode
    public init(
        text: Binding<String>,
        isEditable: Bool = true,
        language: CodeLanguage = .json,
        fontSize: CGFloat = 12,
        showLineNumbers: Bool = true,
        indentString: String = "  ",
        searchQuery: String = "",
        currentMatchIndex: Int = 0,
        isCaseSensitive: Bool = false,
        onFormatAction: (() -> Void)? = nil,
        onMatchCountChanged: ((Int) -> Void)? = nil
    ) {
        self._text = text
        self.isEditable = isEditable
        self.language = language
        self.fontSize = fontSize
        self.showLineNumbers = showLineNumbers
        self.indentString = indentString
        self.searchQuery = searchQuery
        self.currentMatchIndex = currentMatchIndex
        self.isCaseSensitive = isCaseSensitive
        self.onFormatAction = onFormatAction
        self.onMatchCountChanged = onMatchCountChanged
    }

    // Convenience initializer for read-only static text
    public init(
        text: String,
        isEditable: Bool = false,
        language: CodeLanguage = .json,
        fontSize: CGFloat = 12,
        showLineNumbers: Bool = true,
        indentString: String = "  ",
        searchQuery: String = "",
        currentMatchIndex: Int = 0,
        isCaseSensitive: Bool = false,
        onFormatAction: (() -> Void)? = nil,
        onMatchCountChanged: ((Int) -> Void)? = nil
    ) {
        self._text = .constant(text)
        self.isEditable = isEditable
        self.language = language
        self.fontSize = fontSize
        self.showLineNumbers = showLineNumbers
        self.indentString = indentString
        self.searchQuery = searchQuery
        self.currentMatchIndex = currentMatchIndex
        self.isCaseSensitive = isCaseSensitive
        self.onFormatAction = onFormatAction
        self.onMatchCountChanged = onMatchCountChanged
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let contentSize = scrollView.contentSize
        let textView = CodeTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: showLineNumbers ? 44 : 8, height: 8)

        textView.isRichText = false
        textView.importsGraphics = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .textColor
        textView.indentString = indentString
        textView.showLineNumbers = showLineNumbers
        textView.language = language
        textView.fontSize = fontSize
        textView.onFormatAction = onFormatAction
        textView.onMatchCountChanged = onMatchCountChanged
        textView.searchQuery = searchQuery
        textView.currentMatchIndex = currentMatchIndex
        textView.isCaseSensitive = isCaseSensitive

        // In-editor Find Bar support
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.parent = self
        textView.delegate = context.coordinator

        // Set initial text and highlighting
        context.coordinator.setExternalText(text, language: language, fontSize: fontSize)

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = context.coordinator.textView else { return }

        tv.isEditable = isEditable
        tv.indentString = indentString
        tv.showLineNumbers = showLineNumbers
        tv.language = language
        tv.fontSize = fontSize
        tv.onFormatAction = onFormatAction
        tv.onMatchCountChanged = onMatchCountChanged

        tv.isCaseSensitive = isCaseSensitive
        tv.currentMatchIndex = currentMatchIndex
        if tv.searchQuery != searchQuery {
            tv.searchQuery = searchQuery
        } else {
            tv.scrollToCurrentMatch()
        }

        // Only update if text was changed from outside
        if !context.coordinator.isApplyingHighlight && context.coordinator.lastKnownText != text {
            context.coordinator.setExternalText(text, language: language, fontSize: fontSize)
        } else if context.coordinator.lastLanguage != language || context.coordinator.lastFontSize != fontSize {
            context.coordinator.updateLanguageOrFont(language: language, fontSize: fontSize)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator
    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacCodeEditorView
        weak var textView: CodeTextView?
        var lastKnownText: String = ""
        var lastLanguage: CodeLanguage = .json
        var lastFontSize: CGFloat = 12

        var isUpdatingFromSwiftUI: Bool = false
        var isApplyingHighlight: Bool = false
        var highlightTask: Task<Void, Never>? = nil

        init(_ parent: MacCodeEditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI, !isApplyingHighlight else { return }
            guard let tv = textView else { return }
            let currentString = tv.string

            lastKnownText = currentString
            parent.text = currentString

            tv.needsDisplay = true
            scheduleHighlight(text: currentString, language: lastLanguage, fontSize: lastFontSize)
        }

        func setExternalText(_ newText: String, language: CodeLanguage, fontSize: CGFloat) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            lastKnownText = newText
            lastLanguage = language
            lastFontSize = fontSize
            highlightTask?.cancel()

            isUpdatingFromSwiftUI = true
            let prevSel = tv.selectedRange()

            let highlighted = CodeSyntaxHighlighter.highlight(text: newText, language: language, fontSize: fontSize)
            storage.setAttributedString(highlighted)

            if prevSel.location <= (newText as NSString).length {
                tv.setSelectedRange(prevSel)
            }
            tv.updateGutterWidth(for: newText)
            tv.updateHighlights()
            tv.needsDisplay = true
            isUpdatingFromSwiftUI = false
        }

        func updateLanguageOrFont(language: CodeLanguage, fontSize: CGFloat) {
            lastLanguage = language
            lastFontSize = fontSize
            guard let tv = textView else { return }
            scheduleHighlight(text: tv.string, language: language, fontSize: fontSize)
        }

        private func scheduleHighlight(text: String, language: CodeLanguage, fontSize: CGFloat) {
            highlightTask?.cancel()
            highlightTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled, let self = self, let tv = self.textView, let storage = tv.textStorage else { return }
                guard storage.string == text else { return }

                let highlighted = CodeSyntaxHighlighter.highlight(text: text, language: language, fontSize: fontSize)
                guard !Task.isCancelled, storage.string == text else { return }

                self.isApplyingHighlight = true
                storage.beginEditing()
                highlighted.enumerateAttributes(in: NSRange(location: 0, length: highlighted.length), options: []) { attrs, range, _ in
                    storage.setAttributes(attrs, range: range)
                }
                storage.endEditing()
                self.isApplyingHighlight = false

                tv.updateGutterWidth(for: text)
                tv.needsDisplay = true
            }
        }
    }
}

// MARK: - CodeTextView with Full Keyboard Support, Word Highlighting, and Built-in Gutter
final class CodeTextView: NSTextView {
    var indentString: String = "  "
    var showLineNumbers: Bool = true
    var gutterWidth: CGFloat = 40
    var language: CodeLanguage = .plain
    var fontSize: CGFloat = 12
    var onFormatAction: (() -> Void)? = nil
    var onMatchCountChanged: ((Int) -> Void)? = nil

    // Highlights state
    private(set) var matchedWordRanges: [NSRange] = []
    private(set) var matchingBracketPairs: [NSRange] = []
    private(set) var currentCursorLineRange: NSRange? = nil

    // Search state
    var searchQuery: String = "" {
        didSet {
            if oldValue != searchQuery {
                updateSearchMatches()
            }
        }
    }
    var currentMatchIndex: Int = 0 {
        didSet {
            if oldValue != currentMatchIndex {
                scrollToCurrentMatch()
            }
        }
    }
    var isCaseSensitive: Bool = false {
        didSet {
            if oldValue != isCaseSensitive {
                updateSearchMatches()
            }
        }
    }
    private(set) var matchedSearchRanges: [NSRange] = []

    func updateSearchMatches() {
        guard !searchQuery.isEmpty else {
            if !matchedSearchRanges.isEmpty {
                matchedSearchRanges = []
                onMatchCountChanged?(0)
                needsDisplay = true
            }
            return
        }

        let text = self.string as NSString
        guard text.length > 0 else {
            matchedSearchRanges = []
            onMatchCountChanged?(0)
            needsDisplay = true
            return
        }

        var matches: [NSRange] = []
        let maxMatches = 2000
        var searchLocation = 0
        let options: NSString.CompareOptions = isCaseSensitive ? [.literal] : [.caseInsensitive]

        while searchLocation < text.length && matches.count < maxMatches {
            let searchRange = NSRange(location: searchLocation, length: text.length - searchLocation)
            let found = text.range(of: searchQuery, options: options, range: searchRange)
            if found.location == NSNotFound { break }
            matches.append(found)
            searchLocation = found.location + max(1, found.length)
        }

        matchedSearchRanges = matches
        onMatchCountChanged?(matches.count)
        scrollToCurrentMatch()
        needsDisplay = true
    }

    func scrollToCurrentMatch() {
        guard !matchedSearchRanges.isEmpty else { return }
        let idx = min(max(0, currentMatchIndex), matchedSearchRanges.count - 1)
        let targetRange = matchedSearchRanges[idx]
        setSelectedRange(targetRange)
        scrollRangeToVisible(targetRange)
        needsDisplay = true
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        updateHighlights()
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
        updateHighlights()
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        updateHighlights()
    }

    override func didChangeText() {
        super.didChangeText()
        if !searchQuery.isEmpty {
            updateSearchMatches()
        }
        updateHighlights()
    }

    // MARK: - Highlights Calculation
    func updateHighlights() {
        updateCurrentLine()
        updateBracketMatching()
        updateOccurrenceMatches()
        needsDisplay = true
    }

    private func updateCurrentLine() {
        let sel = selectedRange()
        let text = self.string as NSString
        guard text.length > 0 else {
            currentCursorLineRange = nil
            return
        }
        let loc = min(sel.location, max(0, text.length - 1))
        var lineStart = 0
        var lineEnd = 0
        text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil, for: NSRange(location: loc, length: 0))
        currentCursorLineRange = NSRange(location: lineStart, length: max(0, lineEnd - lineStart))
    }

    private func updateBracketMatching() {
        let sel = selectedRange()
        let text = self.string as NSString
        guard text.length > 0 else {
            matchingBracketPairs = []
            return
        }

        var bracketIndex: Int? = nil
        let bracketChars: Set<unichar> = [40, 41, 91, 93, 123, 125] // ( ) [ ] { }

        if sel.location > 0 && sel.location <= text.length {
            let prevChar = text.character(at: sel.location - 1)
            if bracketChars.contains(prevChar) {
                bracketIndex = sel.location - 1
            }
        }
        if bracketIndex == nil && sel.location < text.length {
            let currChar = text.character(at: sel.location)
            if bracketChars.contains(currChar) {
                bracketIndex = sel.location
            }
        }

        guard let idx = bracketIndex else {
            matchingBracketPairs = []
            return
        }

        let char = text.character(at: idx)
        let pairs: [unichar: (match: unichar, forward: Bool)] = [
            40: (41, true),   // ( -> )
            41: (40, false),  // ) -> (
            91: (93, true),   // [ -> ]
            93: (91, false),  // ] -> [
            123: (125, true), // { -> }
            125: (123, false) // } -> {
        ]
        guard let pair = pairs[char] else {
            matchingBracketPairs = []
            return
        }

        var depth = 1
        let forward = pair.forward
        let target = pair.match
        var curr = forward ? idx + 1 : idx - 1
        let limit = forward ? min(text.length, idx + 8000) : max(0, idx - 8000)
        var matchedIdx: Int? = nil

        while forward ? (curr < limit) : (curr >= limit) {
            let c = text.character(at: curr)
            if c == char {
                depth += 1
            } else if c == target {
                depth -= 1
                if depth == 0 {
                    matchedIdx = curr
                    break
                }
            }
            curr += forward ? 1 : -1
        }

        if let mIdx = matchedIdx {
            matchingBracketPairs = [NSRange(location: idx, length: 1), NSRange(location: mIdx, length: 1)]
        } else {
            matchingBracketPairs = [NSRange(location: idx, length: 1)]
        }
    }

    private func updateOccurrenceMatches() {
        let sel = selectedRange()
        let text = self.string as NSString
        guard text.length > 0 else {
            matchedWordRanges = []
            onMatchCountChanged?(0)
            return
        }

        var searchToken = ""
        var isWordIdentifier = false

        if sel.length > 0 && sel.length <= 100 {
            let rawSelected = text.substring(with: sel)
            let trimmed = rawSelected.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.contains("\n") && !trimmed.contains("\r") {
                searchToken = trimmed
                isWordIdentifier = trimmed.allSatisfy { ch in
                    ch.isLetter || ch.isNumber || ch == "_" || ch == "$"
                }
            }
        }

        guard !searchToken.isEmpty else {
            if !matchedWordRanges.isEmpty {
                matchedWordRanges = []
                onMatchCountChanged?(0)
            }
            return
        }

        var matches: [NSRange] = []
        let maxMatches = 500
        var searchLocation = 0

        while searchLocation < text.length && matches.count < maxMatches {
            let searchRange = NSRange(location: searchLocation, length: text.length - searchLocation)
            let found = text.range(of: searchToken, options: [.literal], range: searchRange)
            if found.location == NSNotFound { break }

            if isWordIdentifier {
                var valid = true
                if found.location > 0 {
                    let prevChar = text.character(at: found.location - 1)
                    if isWordChar(prevChar) { valid = false }
                }
                let nextIndex = found.location + found.length
                if nextIndex < text.length {
                    let nextChar = text.character(at: nextIndex)
                    if isWordChar(nextChar) { valid = false }
                }
                if valid {
                    matches.append(found)
                }
            } else {
                matches.append(found)
            }
            searchLocation = found.location + max(1, found.length)
        }

        matchedWordRanges = matches
        onMatchCountChanged?(matches.count)
    }

    private func isWordChar(_ c: unichar) -> Bool {
        if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95 || c == 36 {
            return true
        }
        if c > 127, let scalar = UnicodeScalar(c) {
            return CharacterSet.alphanumerics.contains(scalar)
        }
        return false
    }

    // MARK: - Auto-Closing and Selection Wrapping
    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard isEditable else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }

        guard let str = string as? String else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }

        let sel = replacementRange.location != NSNotFound ? replacementRange : selectedRange()
        let text = self.string as NSString

        let pairs: [String: String] = [
            "(": ")",
            "[": "]",
            "{": "}",
            "\"": "\"",
            "'": "'",
            "`": "`"
        ]
        let closingChars: Set<Character> = [")", "]", "}", "\"", "'", "`"]

        // Case 1: Over-type closing bracket when cursor is immediately before it
        if str.count == 1, closingChars.contains(Character(str)), sel.length == 0, sel.location < text.length {
            let nextChar = text.character(at: sel.location)
            if UnicodeScalar(nextChar) == UnicodeScalar(str) {
                setSelectedRange(NSRange(location: sel.location + 1, length: 0))
                updateHighlights()
                return
            }
        }

        // Case 2: Wrapping selection
        if let closing = pairs[str], sel.length > 0 && sel.location + sel.length <= text.length {
            let selectedContent = text.substring(with: sel)
            let wrapped = "\(str)\(selectedContent)\(closing)"
            super.insertText(wrapped, replacementRange: sel)
            setSelectedRange(NSRange(location: sel.location + str.count, length: selectedContent.count))
            updateHighlights()
            return
        }

        // Case 3: Auto-close empty pair
        if let closing = pairs[str], sel.length == 0 {
            let pair = "\(str)\(closing)"
            super.insertText(pair, replacementRange: sel)
            setSelectedRange(NSRange(location: sel.location + str.count, length: 0))
            updateHighlights()
            return
        }

        super.insertText(string, replacementRange: replacementRange)
    }

    override func deleteBackward(_ sender: Any?) {
        guard isEditable else {
            super.deleteBackward(sender)
            return
        }
        let sel = selectedRange()
        let text = self.string as NSString
        if sel.length == 0 && sel.location > 0 && sel.location < text.length {
            let prevChar = text.character(at: sel.location - 1)
            let nextChar = text.character(at: sel.location)
            let isPair = (prevChar == 40 && nextChar == 41)   // ()
                      || (prevChar == 91 && nextChar == 93)   // []
                      || (prevChar == 123 && nextChar == 125) // {}
                      || (prevChar == 34 && nextChar == 34)   // ""
                      || (prevChar == 39 && nextChar == 39)   // ''
                      || (prevChar == 96 && nextChar == 96)   // ``
            if isPair {
                let deleteRange = NSRange(location: sel.location - 1, length: 2)
                insertText("", replacementRange: deleteRange)
                updateHighlights()
                return
            }
        }
        super.deleteBackward(sender)
    }

    override func insertTab(_ sender: Any?) {
        if isEditable {
            insertText(indentString, replacementRange: selectedRange())
        } else {
            super.insertTab(sender)
        }
    }

    override func paste(_ sender: Any?) {
        guard isEditable else { return }
        if let str = NSPasteboard.general.string(forType: .string) {
            insertText(str, replacementRange: selectedRange())
            updateHighlights()
        } else {
            super.paste(sender)
        }
    }

    // MARK: - Sublime Text Keyboard Shortcuts
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags == .command {
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            switch chars {
            case "c":
                copy(nil)
                return true
            case "a":
                selectAll(nil)
                return true
            case "f":
                let item = NSMenuItem(title: "", action: #selector(performFindPanelAction(_:)), keyEquivalent: "")
                item.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
                performFindPanelAction(item)
                return true
            case "g":
                let item = NSMenuItem(title: "", action: #selector(performFindPanelAction(_:)), keyEquivalent: "")
                item.tag = Int(NSFindPanelAction.next.rawValue)
                performFindPanelAction(item)
                return true
            case "d":
                selectNextOccurrence()
                return true
            case "v" where isEditable:
                paste(nil)
                return true
            case "x" where isEditable:
                cut(nil)
                return true
            case "z" where isEditable:
                undoManager?.undo()
                return true
            case "/" where isEditable:
                toggleComment()
                return true
            case "\r", "\n":
                if let onFormat = onFormatAction {
                    onFormat()
                    return true
                }
            default:
                break
            }
        } else if flags == [.command, .shift] {
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            switch chars {
            case "z" where isEditable:
                undoManager?.redo()
                return true
            case "g":
                let item = NSMenuItem(title: "", action: #selector(performFindPanelAction(_:)), keyEquivalent: "")
                item.tag = Int(NSFindPanelAction.previous.rawValue)
                performFindPanelAction(item)
                return true
            case "d" where isEditable:
                duplicateCurrentLine()
                return true
            case "k" where isEditable:
                deleteCurrentLine()
                return true
            default:
                break
            }
        } else if flags == .option && isEditable {
            if event.keyCode == 126 { // Up arrow
                moveLine(direction: -1)
                return true
            } else if event.keyCode == 125 { // Down arrow
                moveLine(direction: 1)
                return true
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Sublime Actions
    func selectNextOccurrence() {
        let sel = selectedRange()
        let text = self.string as NSString
        guard text.length > 0 else { return }

        if sel.length == 0 {
            let wordRange = findWordAt(sel.location, in: text)
            if wordRange.length > 0 {
                setSelectedRange(wordRange)
                scrollRangeToVisible(wordRange)
                updateHighlights()
            }
            return
        }

        let target = text.substring(with: sel)
        guard !target.isEmpty else { return }

        let searchStart = sel.location + sel.length
        var foundRange = NSRange(location: NSNotFound, length: 0)

        if searchStart < text.length {
            let forwardRange = NSRange(location: searchStart, length: text.length - searchStart)
            foundRange = text.range(of: target, options: [.literal], range: forwardRange)
        }

        if foundRange.location == NSNotFound && sel.location > 0 {
            let wrapRange = NSRange(location: 0, length: sel.location)
            foundRange = text.range(of: target, options: [.literal], range: wrapRange)
        }

        if foundRange.location != NSNotFound {
            setSelectedRange(foundRange)
            scrollRangeToVisible(foundRange)
            updateHighlights()
        }
    }

    private func findWordAt(_ location: Int, in text: NSString) -> NSRange {
        guard text.length > 0 else { return NSRange(location: 0, length: 0) }
        let loc = min(max(0, location), text.length - 1)
        var start = loc
        if !isWordChar(text.character(at: start)) && start > 0 && isWordChar(text.character(at: start - 1)) {
            start = start - 1
        }
        guard isWordChar(text.character(at: start)) else { return NSRange(location: 0, length: 0) }

        var left = start
        while left > 0 && isWordChar(text.character(at: left - 1)) {
            left -= 1
        }
        var right = start
        while right < text.length - 1 && isWordChar(text.character(at: right + 1)) {
            right += 1
        }
        return NSRange(location: left, length: right - left + 1)
    }

    func duplicateCurrentLine() {
        guard isEditable else { return }
        let sel = selectedRange()
        let text = self.string as NSString
        guard text.length > 0 else {
            insertText("\n", replacementRange: sel)
            return
        }

        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: sel)

        let lineContent = text.substring(with: NSRange(location: lineStart, length: contentsEnd - lineStart))
        let insertString = "\n" + lineContent

        insertText(insertString, replacementRange: NSRange(location: contentsEnd, length: 0))
        let newCursorPos = contentsEnd + 1 + min(sel.location - lineStart, lineContent.count)
        setSelectedRange(NSRange(location: min(newCursorPos, (self.string as NSString).length), length: 0))
        updateHighlights()
    }

    func deleteCurrentLine() {
        guard isEditable else { return }
        let sel = selectedRange()
        let text = self.string as NSString
        guard text.length > 0 else { return }

        var lineStart = 0
        var lineEnd = 0
        text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil, for: sel)

        let deleteRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        insertText("", replacementRange: deleteRange)
        updateHighlights()
    }

    func moveLine(direction: Int) {
        guard isEditable else { return }
        let sel = selectedRange()
        let text = self.string as NSString
        guard text.length > 0 else { return }

        var lineStart = 0
        var lineEnd = 0
        text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil, for: sel)

        if direction < 0 {
            guard lineStart > 0 else { return }
            var prevStart = 0
            var prevEnd = 0
            text.getLineStart(&prevStart, end: &prevEnd, contentsEnd: nil, for: NSRange(location: lineStart - 1, length: 0))

            let currText = text.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
            let prevText = text.substring(with: NSRange(location: prevStart, length: prevEnd - prevStart))

            let totalRange = NSRange(location: prevStart, length: lineEnd - prevStart)
            let combined = currText.hasSuffix("\n") ? (currText + prevText) : (currText + "\n" + prevText.trimmingCharacters(in: .newlines) + "\n")
            insertText(combined, replacementRange: totalRange)
            setSelectedRange(NSRange(location: prevStart + (sel.location - lineStart), length: sel.length))
        } else {
            guard lineEnd < text.length else { return }
            var nextStart = 0
            var nextEnd = 0
            text.getLineStart(&nextStart, end: &nextEnd, contentsEnd: nil, for: NSRange(location: lineEnd, length: 0))

            let currText = text.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
            let nextText = text.substring(with: NSRange(location: nextStart, length: nextEnd - nextStart))

            let totalRange = NSRange(location: lineStart, length: nextEnd - lineStart)
            let combined = nextText.hasSuffix("\n") ? (nextText + currText) : (nextText + "\n" + currText.trimmingCharacters(in: .newlines) + "\n")
            insertText(combined, replacementRange: totalRange)
            let newStart = lineStart + (nextEnd - nextStart)
            setSelectedRange(NSRange(location: newStart + (sel.location - lineStart), length: sel.length))
        }
        updateHighlights()
    }

    func toggleComment() {
        guard isEditable else { return }
        let sel = selectedRange()
        let text = self.string as NSString
        guard text.length > 0 else { return }

        let commentPrefix: String
        switch language {
        case .sql:
            commentPrefix = "-- "
        case .yaml:
            commentPrefix = "# "
        case .css:
            commentPrefix = "/* "
        case .xml:
            commentPrefix = "<!-- "
        default:
            commentPrefix = "// "
        }

        var lineStart = 0
        var lineEnd = 0
        text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil, for: sel)

        let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        let fullLine = text.substring(with: lineRange)

        let lines = fullLine.components(separatedBy: "\n")
        let hasTrailingNewline = fullLine.hasSuffix("\n")
        let actualLines = hasTrailingNewline ? Array(lines.dropLast()) : lines

        let cleanPrefix = commentPrefix.trimmingCharacters(in: .whitespaces)
        let allCommented = actualLines.allSatisfy { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || trimmed.hasPrefix(cleanPrefix)
        }

        var newLines: [String] = []
        for line in actualLines {
            if allCommented {
                if let r = line.range(of: commentPrefix) {
                    var l = line
                    l.removeSubrange(r)
                    newLines.append(l)
                } else if let r = line.range(of: cleanPrefix) {
                    var l = line
                    l.removeSubrange(r)
                    newLines.append(l)
                } else {
                    newLines.append(line)
                }
            } else {
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    newLines.append(line)
                } else {
                    let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" })
                    let rest = line.dropFirst(leadingSpaces.count)
                    newLines.append("\(leadingSpaces)\(commentPrefix)\(rest)")
                }
            }
        }

        var replaced = newLines.joined(separator: "\n")
        if hasTrailingNewline {
            replaced.append("\n")
        }

        insertText(replaced, replacementRange: lineRange)
        setSelectedRange(NSRange(location: lineStart, length: (replaced as NSString).length))
        updateHighlights()
    }

    func updateGutterWidth(for text: String) {
        guard showLineNumbers else { return }
        let lines = max(1, text.components(separatedBy: "\n").count)
        let digits = "\(lines)".count
        let targetWidth = max(38, CGFloat(digits * 9 + 18))
        if abs(gutterWidth - targetWidth) > 1 {
            gutterWidth = targetWidth
            textContainerInset = NSSize(width: gutterWidth + 8, height: 8)
        }
    }

    // MARK: - Custom Rendering: Gutter, Line Highlight, Matching Words & Brackets
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let textColor = isDark ? NSColor(white: 0.45, alpha: 1.0) : NSColor(white: 0.58, alpha: 1.0)

        guard let layoutManager = self.layoutManager,
              let textContainer = self.textContainer else { return }

        let origin = textContainerOrigin

        // 1. Draw Active Line Highlight
        if let lineRange = currentCursorLineRange {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            if glyphRange.length > 0 {
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
                let startX = showLineNumbers ? gutterWidth : 0
                let fullWidth = max(bounds.width - startX, 0)
                let currentLineRect = NSRect(x: startX, y: lineRect.origin.y + origin.y, width: fullWidth, height: lineRect.height)
                if currentLineRect.intersects(rect) {
                    let lineBg = isDark ? NSColor(white: 1.0, alpha: 0.04) : NSColor(white: 0.0, alpha: 0.035)
                    lineBg.setFill()
                    currentLineRect.fill()
                }
            }
        }

        // 2. Draw Search Matches or Word Occurrences Highlight
        if !matchedSearchRanges.isEmpty {
            let activeIdx = min(max(0, currentMatchIndex), matchedSearchRanges.count - 1)
            let regularFill = isDark
                ? NSColor(red: 0.95, green: 0.75, blue: 0.10, alpha: 0.28)
                : NSColor(red: 0.95, green: 0.70, blue: 0.05, alpha: 0.22)
            let regularStroke = isDark
                ? NSColor(red: 1.00, green: 0.85, blue: 0.20, alpha: 0.60)
                : NSColor(red: 0.85, green: 0.55, blue: 0.00, alpha: 0.55)

            let activeFill = isDark
                ? NSColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 0.55)
                : NSColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 0.40)
            let activeStroke = isDark
                ? NSColor(red: 1.00, green: 0.75, blue: 0.10, alpha: 1.00)
                : NSColor(red: 0.90, green: 0.40, blue: 0.00, alpha: 0.90)

            for (i, matchRange) in matchedSearchRanges.enumerated() {
                let isActive = (i == activeIdx)
                let glyphRange = layoutManager.glyphRange(forCharacterRange: matchRange, actualCharacterRange: nil)
                guard glyphRange.length > 0 else { continue }
                layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: textContainer) { boxRect, _ in
                    let highlightRect = boxRect.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -1.0, dy: -0.5)
                    if highlightRect.intersects(rect) {
                        let path = NSBezierPath(roundedRect: highlightRect, xRadius: 3.0, yRadius: 3.0)
                        if isActive {
                            activeFill.setFill()
                            path.fill()
                            activeStroke.setStroke()
                            path.lineWidth = 1.5
                            path.stroke()
                        } else {
                            regularFill.setFill()
                            path.fill()
                            regularStroke.setStroke()
                            path.lineWidth = 1.0
                            path.stroke()
                        }
                    }
                }
            }
        } else if !matchedWordRanges.isEmpty {
            let fillColor = isDark
                ? NSColor(red: 0.28, green: 0.55, blue: 0.98, alpha: 0.22)
                : NSColor(red: 0.15, green: 0.45, blue: 0.90, alpha: 0.16)
            let strokeColor = isDark
                ? NSColor(red: 0.45, green: 0.72, blue: 1.00, alpha: 0.70)
                : NSColor(red: 0.15, green: 0.45, blue: 0.90, alpha: 0.60)

            for matchRange in matchedWordRanges {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: matchRange, actualCharacterRange: nil)
                guard glyphRange.length > 0 else { continue }
                layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: textContainer) { boxRect, _ in
                    let highlightRect = boxRect.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -1.0, dy: -0.5)
                    if highlightRect.intersects(rect) {
                        let path = NSBezierPath(roundedRect: highlightRect, xRadius: 3.0, yRadius: 3.0)
                        fillColor.setFill()
                        path.fill()
                        strokeColor.setStroke()
                        path.lineWidth = 1.0
                        path.stroke()
                    }
                }
            }
        }

        // 3. Draw Matching Brackets Highlight
        if !matchingBracketPairs.isEmpty {
            let bracketBorder = isDark
                ? NSColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.90)
                : NSColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 0.85)
            let bracketFill = isDark
                ? NSColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.25)
                : NSColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 0.20)

            for bRange in matchingBracketPairs {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: bRange, actualCharacterRange: nil)
                guard glyphRange.length > 0 else { continue }
                let boxRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                let r = boxRect.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -0.5, dy: -0.5)
                if r.intersects(rect) {
                    let path = NSBezierPath(roundedRect: r, xRadius: 2.5, yRadius: 2.5)
                    bracketFill.setFill()
                    path.fill()
                    bracketBorder.setStroke()
                    path.lineWidth = 1.2
                    path.stroke()
                }
            }
        }

        // 4. Draw Line Number Gutter if enabled
        if showLineNumbers {
            let gutterBg = isDark ? NSColor(white: 0.13, alpha: 1.0) : NSColor(white: 0.96, alpha: 1.0)
            let strokeColor = isDark ? NSColor(white: 0.22, alpha: 1.0) : NSColor(white: 0.88, alpha: 1.0)

            // Draw gutter background
            let gutterRect = NSRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)
            gutterBg.setFill()
            gutterRect.fill()

            // Draw gutter separator line
            let borderRect = NSRect(x: gutterWidth - 1, y: rect.minY, width: 1, height: rect.height)
            strokeColor.setFill()
            borderRect.fill()

            let textNSString = self.string as NSString
            let textLength = textNSString.length
            let fontRegular = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            let fontBold = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)

            let regularAttrs: [NSAttributedString.Key: Any] = [.font: fontRegular, .foregroundColor: textColor]

            guard textLength > 0 else {
                let y = origin.y + 1
                ("1" as NSString).draw(at: NSPoint(x: gutterWidth - 16, y: y), withAttributes: regularAttrs)
                return
            }

            let glyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
            var lineNumber = 1

            if charIndex > 0 && charIndex <= textLength {
                var idx = 0
                while idx < charIndex {
                    var lineEnd = 0
                    textNSString.getLineStart(nil, end: &lineEnd, contentsEnd: nil, for: NSRange(location: idx, length: 0))
                    if lineEnd <= idx { break }
                    idx = lineEnd
                    lineNumber += 1
                }
            }

            var glyphIndex = glyphRange.location
            while glyphIndex < NSMaxRange(glyphRange) {
                let chIdx = layoutManager.characterIndexForGlyph(at: glyphIndex)
                var lineGlyphRange = NSRange(location: 0, length: 0)
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)

                var charLineStart = 0
                textNSString.getLineStart(&charLineStart, end: nil, contentsEnd: nil, for: NSRange(location: chIdx, length: 0))

                if chIdx == charLineStart {
                    let isCurrentLine: Bool
                    if let cur = currentCursorLineRange {
                        isCurrentLine = charLineStart >= cur.location && charLineStart < (cur.location + cur.length)
                    } else {
                        isCurrentLine = false
                    }

                    let numAttrs: [NSAttributedString.Key: Any] = isCurrentLine
                        ? [.font: fontBold, .foregroundColor: isDark ? NSColor.white : NSColor.black]
                        : regularAttrs

                    let numStr = "\(lineNumber)"
                    let strSize = (numStr as NSString).size(withAttributes: numAttrs)
                    let y = lineRect.origin.y + origin.y + (lineRect.height - strSize.height) / 2
                    (numStr as NSString).draw(at: NSPoint(x: gutterWidth - strSize.width - 8, y: y), withAttributes: numAttrs)
                    lineNumber += 1
                }

                glyphIndex = NSMaxRange(lineGlyphRange)
            }
        }

        // 5. Draw Placeholder when empty
        if string.isEmpty {
            let placeholderFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            let placeholderColor = isDark ? NSColor(white: 0.35, alpha: 1.0) : NSColor(white: 0.65, alpha: 1.0)
            let placeholderAttrs: [NSAttributedString.Key: Any] = [
                .font: placeholderFont,
                .foregroundColor: placeholderColor
            ]
            let placeholderText = "// 支持 ⌘Return 一键美化 · ⌘F 搜索 · ⌘D 选中相同词 · ⇧⌘D 复制行 · ⌘/ 注释"
            let drawX = showLineNumbers ? gutterWidth + 8 : 8
            (placeholderText as NSString).draw(at: NSPoint(x: drawX, y: origin.y + 1), withAttributes: placeholderAttrs)
        }
    }
}
