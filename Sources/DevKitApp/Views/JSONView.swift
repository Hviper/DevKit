import SwiftUI
import DevKitCore
import AppKit

public struct JSONView: View {
    @State private var inputText: String = "{\n  \"name\": \"DevKit\",\n  \"version\": \"1.0.1\",\n  \"features\": [\n    \"Diff\",\n    \"URL\",\n    \"Base64\",\n    \"Hash\",\n    \"JSON\",\n    \"UUID\",\n    \"Timestamp\",\n    \"Regex\",\n    \"JWT\"\n  ],\n  \"metadata\": {\n    \"author\": \"DevKit Team\",\n    \"license\": \"MIT\",\n    \"stars\": 2000\n  },\n  \"offline\": true\n}"
    @State private var outputText: String = ""
    @State private var rootNode: JSONTreeNode? = nil
    @State private var indent: JSONFormatterTool.IndentStyle = .twoSpaces
    @State private var formatMode: JSONFormatterTool.FormatMode = .pretty
    @State private var viewDisplayMode: ViewDisplayMode = .tree
    @State private var layoutDirection: LayoutDirection = .horizontal
    @State private var errorMessage: String? = nil
    @State private var showCopyFeedback: Bool = false
    @State private var formatTask: Task<Void, Never>? = nil

    // JSONPath filter state
    @State private var showPathBar: Bool = false
    @State private var jsonPathQuery: String = ""

    // Code model export state
    @State private var showModelExportSheet: Bool = false
    @State private var exportLanguage: JSONFormatterTool.ModelLanguage = .typeScript
    @State private var exportRootName: String = "Root"
    @State private var generatedModelCode: String = ""
    @State private var showModelCopyFeedback: Bool = false

    // Search state
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @State private var isFindCaseSensitive: Bool = false
    @State private var findMatchCount: Int = 0
    @State private var currentFindIndex: Int = 0

    enum ViewDisplayMode: String, CaseIterable {
        case tree = "树形折叠"
        case code = "高亮代码"
    }

    enum LayoutDirection: String, CaseIterable {
        case horizontal = "左右分栏"
        case vertical = "上下分栏"
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Controls
            toolbar

            Divider()

            // ⌘F Find Bar
            if showFindBar {
                FindBarView(
                    findText: $findText,
                    isCaseSensitive: $isFindCaseSensitive,
                    matchCount: findMatchCount,
                    currentMatchIndex: currentFindIndex,
                    onPrevious: {
                        if findMatchCount > 0 {
                            currentFindIndex = (currentFindIndex - 1 + findMatchCount) % findMatchCount
                        }
                    },
                    onNext: {
                        if findMatchCount > 0 {
                            currentFindIndex = (currentFindIndex + 1) % findMatchCount
                        }
                    },
                    onClose: {
                        showFindBar = false
                        findText = ""
                    }
                )
                Divider()
            }

            // Draggable Split Area (Default Horizontal side-by-side for JSON)
            if layoutDirection == .horizontal {
                HSplitView {
                    inputArea
                        .frame(minWidth: 220, idealWidth: 350, maxWidth: .infinity)

                    outputArea
                        .frame(minWidth: 240, idealWidth: 420, maxWidth: .infinity)
                }
            } else {
                VSplitView {
                    inputArea
                        .frame(minHeight: 100, idealHeight: 200, maxHeight: .infinity)

                    outputArea
                        .frame(minHeight: 120, idealHeight: 280, maxHeight: .infinity)
                }
            }
        }
        .background(
            Button("") {
                showFindBar.toggle()
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        )
        .onChange(of: inputText) { _ in scheduleFormat() }
        .onChange(of: indent) { _ in scheduleFormat() }
        .onChange(of: formatMode) { _ in scheduleFormat() }
        .onChange(of: jsonPathQuery) { _ in scheduleFormat() }
        .onChange(of: viewDisplayMode) { newMode in
            if newMode == .tree && rootNode == nil && !outputText.isEmpty {
                rootNode = JSONTreeNode.parse(from: outputText)
            }
        }
        .onAppear { scheduleFormat() }
        .sheet(isPresented: $showModelExportSheet) {
            modelExportSheetView
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("模式", selection: $formatMode) {
                Text("美化").tag(JSONFormatterTool.FormatMode.pretty)
                Text("压缩").tag(JSONFormatterTool.FormatMode.minify)
                Text("校验").tag(JSONFormatterTool.FormatMode.validate)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            if formatMode == .pretty {
                Picker("缩进", selection: $indent) {
                    ForEach(JSONFormatterTool.IndentStyle.allCases, id: \.self) { ind in
                        Text(ind.rawValue).tag(ind)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                // Tree vs Code View Switch
                Picker("视图", selection: $viewDisplayMode) {
                    ForEach(ViewDisplayMode.allCases, id: \.self) { vm in
                        Text(vm.rawValue).tag(vm)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            Button {
                tryRepair()
            } label: {
                Label("修复语法", systemImage: "wrench.and.screwdriver")
            }
            .controlSize(.small)
            .help("尝试修复单引号、尾随逗号等非标准格式")

            Button {
                showPathBar.toggle()
            } label: {
                Label("JSONPath", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .controlSize(.small)
            .help("按路径快速过滤节点内容")

            Button {
                showModelExportSheet = true
            } label: {
                Label("导出模型", systemImage: "curlybraces.square")
            }
            .controlSize(.small)
            .help("一键生成 TypeScript 或 Swift 数据结构模型")

            Spacer()

            // Layout direction toggle
            Picker("", selection: $layoutDirection) {
                Image(systemName: "rectangle.split.2x1").tag(LayoutDirection.horizontal)
                Image(systemName: "rectangle.split.1x2").tag(LayoutDirection.vertical)
            }
            .pickerStyle(.segmented)
            .frame(width: 70)
            .help("切换分栏方向（左右/上下）")

            Button {
                showFindBar.toggle()
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .controlSize(.small)
            .help("在 JSON 中搜索 (⌘F)")

            Button("清空") {
                inputText = ""
                outputText = ""
                rootNode = nil
                errorMessage = nil
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("输入 JSON")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text("\(inputText.count) 字符")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))

                Spacer()

                Button("从剪贴板粘贴") {
                    if let clip = NSPasteboard.general.string(forType: .string) {
                        inputText = clip
                    }
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundColor(.accentColor)

                Button("清空") {
                    inputText = ""
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            MacCodeEditorView(
                text: $inputText,
                isEditable: true,
                language: .json,
                fontSize: 12,
                showLineNumbers: true,
                searchQuery: showFindBar ? findText : "",
                currentMatchIndex: currentFindIndex,
                isCaseSensitive: isFindCaseSensitive,
                onMatchCountChanged: { count in
                    if findMatchCount == 0 {
                        findMatchCount = count
                    }
                }
            )
        }
    }

    private var outputArea: some View {
        VStack(spacing: 0) {
            // Unified Output Header
            HStack(spacing: 8) {
                Text("格式化结果")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                if let err = errorMessage {
                    Text("❌ \(err)")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("语法正确")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }

                // Inline Expand / Collapse All buttons in header
                if viewDisplayMode == .tree, let root = rootNode {
                    Divider().frame(height: 12)

                    Button {
                        root.setExpandedRecursively(true)
                    } label: {
                        Label("全部展开", systemImage: "chevron.down.circle")
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(.accentColor)

                    Button {
                        root.setExpandedRecursively(false)
                    } label: {
                        Label("全部折叠", systemImage: "chevron.right.circle")
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if showCopyFeedback {
                    Text("✓ 已复制")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Button {
                    copyOutput()
                } label: {
                    Label("复制结果", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            // JSONPath Search Bar
            if showPathBar {
                HStack(spacing: 8) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .foregroundColor(.accentColor)
                        .font(.caption2)

                    TextField("JSONPath 路径 (如: features[0] 或 metadata.author)", text: $jsonPathQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))

                    if !jsonPathQuery.isEmpty {
                        Button {
                            jsonPathQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            }

            Divider()

            // Content View (Tree or Highlighted Code)
            if viewDisplayMode == .tree && rootNode != nil {
                CollapsibleJSONTreeView(rootNode: rootNode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MacCodeEditorView(
                    text: outputText,
                    isEditable: false,
                    language: .json,
                    fontSize: 12,
                    showLineNumbers: true,
                    searchQuery: showFindBar ? findText : "",
                    currentMatchIndex: currentFindIndex,
                    isCaseSensitive: isFindCaseSensitive,
                    onMatchCountChanged: { count in
                        findMatchCount = count
                        if count == 0 {
                            currentFindIndex = 0
                        } else if currentFindIndex >= count {
                            currentFindIndex = max(0, count - 1)
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Model Export Sheet View
    private var modelExportSheetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "curlybraces.square.fill")
                        .foregroundColor(.accentColor)
                    Text("导出数据模型声明 (Model Generator)")
                        .font(.headline)
                }
                Spacer()
                Button("完成") {
                    showModelExportSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }

            HStack(spacing: 12) {
                Picker("目标语言", selection: $exportLanguage) {
                    ForEach(JSONFormatterTool.ModelLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                HStack(spacing: 4) {
                    Text("根名:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Root", text: $exportRootName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                Spacer()

                Button {
                    copyModelCode()
                } label: {
                    Label(showModelCopyFeedback ? "已复制！" : "复制代码", systemImage: showModelCopyFeedback ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            MacCodeEditorView(text: generatedModelCode, fontSize: 12)
                .frame(minWidth: 540, minHeight: 340)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
        .padding(16)
        .frame(width: 600, height: 460)
        .onChange(of: exportLanguage) { _ in updateGeneratedModel() }
        .onChange(of: exportRootName) { _ in updateGeneratedModel() }
        .onAppear { updateGeneratedModel() }
    }

    private func scheduleFormat() {
        formatTask?.cancel()
        formatTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { return }

            let baseResult = JSONFormatterTool.format(inputText, mode: formatMode, indent: indent)
            let result: Result<String, DevKitError>

            if case .success(let formatted) = baseResult, !jsonPathQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result = JSONFormatterTool.evaluatePath(formatted, path: jsonPathQuery)
            } else {
                result = baseResult
            }

            if !Task.isCancelled {
                await MainActor.run {
                    switch result {
                    case .success(let formatted):
                        self.outputText = formatted
                        self.errorMessage = nil
                        if self.viewDisplayMode == .tree {
                            self.rootNode = JSONTreeNode.parse(from: formatted)
                        } else {
                            self.rootNode = nil
                        }
                    case .failure(let err):
                        self.errorMessage = err.localizedDescription
                        self.rootNode = nil
                    }
                }
            }
        }
    }

    private func updateGeneratedModel() {
        let name = exportRootName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Root" : exportRootName
        switch JSONFormatterTool.generateModel(from: inputText, language: exportLanguage, rootName: name) {
        case .success(let code):
            generatedModelCode = code
        case .failure(let err):
            generatedModelCode = "// 错误: \(err.localizedDescription)"
        }
    }

    private func copyModelCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedModelCode, forType: .string)
        withAnimation { showModelCopyFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showModelCopyFeedback = false }
        }
    }

    private func tryRepair() {
        inputText = JSONFormatterTool.tryRepairJSON(inputText)
        scheduleFormat()
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        withAnimation { showCopyFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopyFeedback = false }
        }
    }
}
