import SwiftUI
import DevKitCore
import AppKit
import UniformTypeIdentifiers

public struct DiffView: View {
    @State private var leftText: String = "function calculateTotal(items) {\n  let total = 0;\n  for (let i = 0; i < items.length; i++) {\n    total += items[i].price;\n  }\n  return total;\n}"
    @State private var rightText: String = "function calculateTotal(items) {\n  // Optimized using reduce\n  return items.reduce((acc, item) => acc + item.price, 0);\n}"
    @State private var ignoreWhitespace: Bool = false
    @State private var ignoreCase: Bool = false
    @State private var viewMode: ViewMode = .sideBySide
    @State private var diffResult: DiffResult = .empty
    @State private var isComputing: Bool = false
    @State private var showInputArea: Bool = true
    @State private var fontSize: CGFloat = 12
    @State private var showCopyFeedback: Bool = false
    @State private var diffTask: Task<Void, Never>? = nil

    // Diff navigation state
    @State private var currentHunkIndex: Int = 0
    @State private var targetScrollId: UUID? = nil
    @State private var focusedRowId: UUID? = nil

    // ⌘F Search state
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @State private var findCaseSensitive: Bool = false
    @State private var currentFindIndex: Int = 0
    @FocusState private var isFindFieldFocused: Bool

    // Drag & drop highlight state
    @State private var isLeftDropTarget: Bool = false
    @State private var isRightDropTarget: Bool = false

    enum ViewMode: String, CaseIterable {
        case sideBySide = "并排对比"
        case unified = "统一视图"
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            toolbar

            // ⌘F Find Bar (shows when active)
            if showFindBar {
                findBar
                Divider()
            }

            Divider()

            // Main Resizable Layout: Input Area (Top) + Diff Result Area (Bottom)
            if showInputArea {
                VSplitView {
                    // Top Input Editors (Resizable Left vs Right via HSplitView)
                    inputSplitView
                        .frame(minHeight: 120, idealHeight: 180, maxHeight: 400)

                    // Bottom Diff Result Area
                    diffResultArea
                        .frame(minHeight: 180, maxHeight: .infinity)
                }
            } else {
                // Maximized Diff Result View
                diffResultArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            // Invisible buttons for global keyboard shortcuts
            Group {
                Button("") { jumpToNextDiff() }
                    .keyboardShortcut("j", modifiers: .command)
                Button("") { jumpToNextDiff() }
                    .keyboardShortcut(.downArrow, modifiers: .option)
                Button("") { jumpToPreviousDiff() }
                    .keyboardShortcut(.upArrow, modifiers: .option)
                Button("") {
                    showFindBar.toggle()
                    if showFindBar {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isFindFieldFocused = true
                        }
                    }
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
        .onChange(of: leftText) { _ in scheduleDiffCalculation() }
        .onChange(of: rightText) { _ in scheduleDiffCalculation() }
        .onChange(of: ignoreWhitespace) { _ in scheduleDiffCalculation() }
        .onChange(of: ignoreCase) { _ in scheduleDiffCalculation() }
        .onChange(of: viewMode) { _ in
            currentHunkIndex = 0
            focusedRowId = nil
        }
        .onChange(of: findText) { _ in
            currentFindIndex = 0
            if !findMatches.isEmpty {
                triggerScroll(to: findMatches[0])
            }
        }
        .onAppear { scheduleDiffCalculation() }
    }

    // MARK: - Toolbar
    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            Toggle("忽略空白", isOn: $ignoreWhitespace)
                .toggleStyle(.checkbox)
                .font(.caption)

            Toggle("忽略大小写", isOn: $ignoreCase)
                .toggleStyle(.checkbox)
                .font(.caption)

            Button {
                swapTexts()
            } label: {
                Label("互换两侧", systemImage: "arrow.left.arrow.right")
            }
            .controlSize(.small)
            .help("互换左右输入文本")

            Button {
                showInputArea.toggle()
            } label: {
                Label(showInputArea ? "折叠输入区" : "展开输入区",
                      systemImage: showInputArea ? "rectangle.topthird.inset.filled" : "rectangle.inset.filled")
            }
            .controlSize(.small)
            .help("折叠输入区以最大化比对视图")

            // Quick Jump to Diff Button in Toolbar
            if !diffResult.isIdentical && !currentDiffHunks.isEmpty {
                Button {
                    jumpToFirstDiff()
                } label: {
                    Label("跳转到diff区", systemImage: "arrow.down.to.line.compact")
                }
                .controlSize(.small)
                .help("快速跳转到首处差异区 (⌘J / ⌥↓)")
            }

            // ⌘F Search Button
            Button {
                showFindBar.toggle()
                if showFindBar {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isFindFieldFocused = true
                    }
                }
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .controlSize(.small)
            .help("在文本对比中搜索 (⌘F)")

            Spacer()

            // Font zoom controls
            HStack(spacing: 4) {
                Button {
                    if fontSize > 10 { fontSize -= 1 }
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .buttonStyle(.plain)
                .help("缩小字体")

                Text("\(Int(fontSize))pt")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 28)

                Button {
                    if fontSize < 20 { fontSize += 1 }
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .buttonStyle(.plain)
                .help("放大字体")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)

            Button {
                leftText = ""
                rightText = ""
            } label: {
                Label("清空", systemImage: "trash")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - ⌘F Find Bar
    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)

            TextField("在比对内容中搜索...", text: $findText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($isFindFieldFocused)
                .onSubmit {
                    jumpToNextFindMatch()
                }

            if !findText.isEmpty {
                Text("\(findMatches.isEmpty ? 0 : currentFindIndex + 1)/\(findMatches.count)")
                    .font(.caption2)
                    .foregroundColor(findMatches.isEmpty ? .red : .secondary)
                    .monospacedDigit()

                Button {
                    jumpToPrevFindMatch()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .disabled(findMatches.isEmpty)
                .help("上一个匹配项 (Shift+Enter / ↑)")

                Button {
                    jumpToNextFindMatch()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .disabled(findMatches.isEmpty)
                .help("下一个匹配项 (Enter / ↓)")
            }

            Toggle("区分大小写", isOn: $findCaseSensitive)
                .toggleStyle(.checkbox)
                .font(.caption2)

            Button {
                showFindBar = false
                findText = ""
                focusedRowId = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("关闭搜索 (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
    }

    // MARK: - Draggable Input Split View
    private var inputSplitView: some View {
        HSplitView {
            // Left Input
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("原始文本 (Original)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text("可拖拽文件入内")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))

                    if !diffResult.isIdentical && !currentDiffHunks.isEmpty {
                        Button("跳转到diff区 ↓") {
                            jumpToFirstDiff()
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    }

                    Spacer()

                    Button("粘贴剪贴板") { pasteToLeft() }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    Button("清空") { leftText = "" }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                MacCodeEditorView(
                    text: $leftText,
                    isEditable: true,
                    language: .plain,
                    fontSize: fontSize,
                    showLineNumbers: true
                )
                .background(isLeftDropTarget ? Color.accentColor.opacity(0.1) : Color(NSColor.textBackgroundColor))
                .onDrop(of: [UTType.fileURL.identifier, UTType.plainText.identifier], isTargeted: $isLeftDropTarget) { providers in
                    handleDrop(providers: providers, isLeft: true)
                }
            }
            .frame(minWidth: 200, maxWidth: .infinity)

            // Right Input
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("对比文本 (Modified)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text("可拖拽文件入内")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))

                    if !diffResult.isIdentical && !currentDiffHunks.isEmpty {
                        Button("跳转到diff区 ↓") {
                            jumpToFirstDiff()
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    }

                    Spacer()

                    Button("粘贴剪贴板") { pasteToRight() }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    Button("清空") { rightText = "" }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                MacCodeEditorView(
                    text: $rightText,
                    isEditable: true,
                    language: .plain,
                    fontSize: fontSize,
                    showLineNumbers: true
                )
                .background(isRightDropTarget ? Color.accentColor.opacity(0.1) : Color(NSColor.textBackgroundColor))
                .onDrop(of: [UTType.fileURL.identifier, UTType.plainText.identifier], isTargeted: $isRightDropTarget) { providers in
                    handleDrop(providers: providers, isLeft: false)
                }
            }
            .frame(minWidth: 200, maxWidth: .infinity)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Diff Result Area
    private var diffResultArea: some View {
        VStack(spacing: 0) {
            // Status & Action Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("比对结果")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if isComputing {
                        ProgressView()
                            .controlSize(.small)
                        Text("计算中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if diffResult.isIdentical {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("两段文本完全一致")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text("+\(diffResult.additions)")
                                .foregroundColor(.green)
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("-\(diffResult.deletions)")
                                .foregroundColor(.red)
                                .font(.caption)
                                .fontWeight(.bold)
                        }

                        // Diff Navigator Controls (上一处 / 下一处 / 计数)
                        if !currentDiffHunks.isEmpty {
                            Divider()
                                .frame(height: 14)

                            HStack(spacing: 4) {
                                Button {
                                    jumpToPreviousDiff()
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(NSColor.controlColor))
                                .cornerRadius(4)
                                .help("跳转到上一处差异 (⌥↑)")

                                Text("差异 \(currentHunkIndex + 1)/\(currentDiffHunks.count)")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.medium)
                                    .monospacedDigit()

                                Button {
                                    jumpToNextDiff()
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(NSColor.controlColor))
                                .cornerRadius(4)
                                .help("跳转到下一处差异 (⌥↓ / ⌘J)")

                                Button {
                                    jumpToFirstDiff()
                                } label: {
                                    Label("首处", systemImage: "arrow.up.to.line")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(NSColor.controlColor))
                                .cornerRadius(4)
                                .help("跳转到首处差异")
                            }
                        }
                    }
                }

                Spacer()

                if showCopyFeedback {
                    Text("✓ 已复制到剪贴板")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }

                Button {
                    copyUnifiedDiff()
                } label: {
                    Label("复制 Diff", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Scrollable Lines - vertical scroll to pin lines to top with ScrollViewReader
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    if viewMode == .sideBySide {
                        sideBySideListView
                    } else {
                        unifiedListView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: targetScrollId) { targetId in
                    guard let targetId = targetId else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(targetId, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Side by Side View
    private var sideBySideListView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(diffResult.sideBySideRows) { row in
                HStack(alignment: .top, spacing: 0) {
                    // Left Column
                    HStack(spacing: 6) {
                        Text(row.leftLine?.lineNumber.map { "\($0)" } ?? "")
                            .frame(width: 34, alignment: .trailing)
                            .foregroundColor(.secondary.opacity(0.6))
                            .font(.system(size: fontSize - 1, design: .monospaced))
                        Text(row.leftLine?.content ?? "")
                            .font(.system(size: fontSize, design: .monospaced))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(leftBackgroundColor(for: row.type))

                    Divider()

                    // Right Column
                    HStack(spacing: 6) {
                        Text(row.rightLine?.lineNumber.map { "\($0)" } ?? "")
                            .frame(width: 34, alignment: .trailing)
                            .foregroundColor(.secondary.opacity(0.6))
                            .font(.system(size: fontSize - 1, design: .monospaced))
                        Text(row.rightLine?.content ?? "")
                            .font(.system(size: fontSize, design: .monospaced))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(rightBackgroundColor(for: row.type))
                }
                .overlay(
                    row.id == focusedRowId ?
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.accentColor, lineWidth: 2)
                        : nil
                )
                .id(row.id)
                Divider()
            }
        }
    }

    // MARK: - Unified View
    private var unifiedListView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(diffResult.unifiedLines) { line in
                HStack(spacing: 6) {
                    Text(prefix(for: line.type))
                        .frame(width: 16)
                        .foregroundColor(textColor(for: line.type))
                        .fontWeight(.bold)
                    Text(line.lineNumber.map { "\($0)" } ?? "")
                        .frame(width: 34, alignment: .trailing)
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: fontSize - 1, design: .monospaced))
                    Text(line.content)
                        .font(.system(size: fontSize, design: .monospaced))
                    Spacer()
                }
                .padding(.vertical, 2)
                .background(unifiedBackgroundColor(for: line.type))
                .overlay(
                    line.id == focusedRowId ?
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.accentColor, lineWidth: 2)
                        : nil
                )
                .id(line.id)
                Divider()
            }
        }
    }

    // MARK: - Diff Hunk Helpers & Navigation
    private var sideBySideDiffHunks: [UUID] {
        var hunkIDs: [UUID] = []
        var inHunk = false
        for row in diffResult.sideBySideRows {
            if row.type != .unchanged {
                if !inHunk {
                    hunkIDs.append(row.id)
                    inHunk = true
                }
            } else {
                inHunk = false
            }
        }
        return hunkIDs
    }

    private var unifiedDiffHunks: [UUID] {
        var hunkIDs: [UUID] = []
        var inHunk = false
        for line in diffResult.unifiedLines {
            if line.type != .unchanged {
                if !inHunk {
                    hunkIDs.append(line.id)
                    inHunk = true
                }
            } else {
                inHunk = false
            }
        }
        return hunkIDs
    }

    private var currentDiffHunks: [UUID] {
        viewMode == .sideBySide ? sideBySideDiffHunks : unifiedDiffHunks
    }

    private var findMatches: [UUID] {
        guard !findText.isEmpty else { return [] }
        let query = findCaseSensitive ? findText : findText.lowercased()

        if viewMode == .sideBySide {
            return diffResult.sideBySideRows.compactMap { row in
                let lContent = row.leftLine?.content ?? ""
                let rContent = row.rightLine?.content ?? ""
                let lMatch = (findCaseSensitive ? lContent : lContent.lowercased()).contains(query)
                let rMatch = (findCaseSensitive ? rContent : rContent.lowercased()).contains(query)
                return (lMatch || rMatch) ? row.id : nil
            }
        } else {
            return diffResult.unifiedLines.compactMap { line in
                let content = findCaseSensitive ? line.content : line.content.lowercased()
                return content.contains(query) ? line.id : nil
            }
        }
    }

    private func jumpToNextDiff() {
        guard !currentDiffHunks.isEmpty else { return }
        currentHunkIndex = (currentHunkIndex + 1) % currentDiffHunks.count
        triggerScroll(to: currentDiffHunks[currentHunkIndex])
    }

    private func jumpToPreviousDiff() {
        guard !currentDiffHunks.isEmpty else { return }
        currentHunkIndex = (currentHunkIndex - 1 + currentDiffHunks.count) % currentDiffHunks.count
        triggerScroll(to: currentDiffHunks[currentHunkIndex])
    }

    private func jumpToFirstDiff() {
        guard !currentDiffHunks.isEmpty else { return }
        currentHunkIndex = 0
        triggerScroll(to: currentDiffHunks[0])
    }

    private func jumpToNextFindMatch() {
        guard !findMatches.isEmpty else { return }
        currentFindIndex = (currentFindIndex + 1) % findMatches.count
        triggerScroll(to: findMatches[currentFindIndex])
    }

    private func jumpToPrevFindMatch() {
        guard !findMatches.isEmpty else { return }
        currentFindIndex = (currentFindIndex - 1 + findMatches.count) % findMatches.count
        triggerScroll(to: findMatches[currentFindIndex])
    }

    private func triggerScroll(to id: UUID) {
        focusedRowId = id
        targetScrollId = nil
        DispatchQueue.main.async {
            self.targetScrollId = id
        }
    }

    private func handleDrop(providers: [NSItemProvider], isLeft: Bool) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                    DispatchQueue.main.async {
                        if isLeft {
                            self.leftText = content
                        } else {
                            self.rightText = content
                        }
                    }
                }
                return true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    if let str = item as? String {
                        DispatchQueue.main.async {
                            if isLeft { self.leftText = str } else { self.rightText = str }
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func leftBackgroundColor(for type: DiffChangeType) -> Color {
        switch type {
        case .deleted, .modified: return Color.red.opacity(0.12)
        default: return Color.clear
        }
    }

    private func rightBackgroundColor(for type: DiffChangeType) -> Color {
        switch type {
        case .added, .modified: return Color.green.opacity(0.12)
        default: return Color.clear
        }
    }

    private func unifiedBackgroundColor(for type: DiffChangeType) -> Color {
        switch type {
        case .added: return Color.green.opacity(0.12)
        case .deleted: return Color.red.opacity(0.12)
        case .modified: return Color.orange.opacity(0.12)
        case .unchanged: return Color.clear
        }
    }

    private func textColor(for type: DiffChangeType) -> Color {
        switch type {
        case .added: return .green
        case .deleted: return .red
        case .modified: return .orange
        case .unchanged: return .secondary
        }
    }

    private func prefix(for type: DiffChangeType) -> String {
        switch type {
        case .added: return "+"
        case .deleted: return "-"
        case .modified: return "~"
        case .unchanged: return " "
        }
    }

    private func swapTexts() {
        let temp = leftText
        leftText = rightText
        rightText = temp
    }

    private func pasteToLeft() {
        if let clip = NSPasteboard.general.string(forType: .string) {
            leftText = clip
        }
    }

    private func pasteToRight() {
        if let clip = NSPasteboard.general.string(forType: .string) {
            rightText = clip
        }
    }

    private func copyUnifiedDiff() {
        let text = diffResult.unifiedLines.map { "\(prefix(for: $0.type)) \($0.content)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation {
            showCopyFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopyFeedback = false
            }
        }
    }

    private func scheduleDiffCalculation() {
        diffTask?.cancel()

        diffTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }

            await MainActor.run {
                self.isComputing = true
            }

            let engine = MyersDiff()
            let result = await engine.diff(
                oldText: leftText,
                newText: rightText,
                ignoreWhitespace: ignoreWhitespace,
                ignoreCase: ignoreCase
            )

            if !Task.isCancelled {
                await MainActor.run {
                    self.diffResult = result
                    self.isComputing = false
                    if self.currentHunkIndex >= self.currentDiffHunks.count {
                        self.currentHunkIndex = 0
                    }
                }
            }
        }
    }
}
