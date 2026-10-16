import SwiftUI
import DevKitCore
import AppKit

public struct CodeFormatterView: View {
    // Current primary code buffer (displayed in Sublime Text single editor)
    @State private var codeText: String = """
    {
      "name": "DevKit",
      "version": "1.0.1",
      "languages": [
        "SQL",
        "JSON",
        "XML",
        "YAML",
        "CSS",
        "Markdown"
      ],
      "editor": "Sublime Text Style",
      "offline": true
    }
    """

    // Secondary buffer used if user switches to Split (前后对比) mode
    @State private var beforeText: String = ""

    // View mode: Default is Sublime Text single editor!
    public enum EditorViewMode: String, CaseIterable, Identifiable {
        case sublime = "单栏编辑 (Sublime)"
        case split = "左右分栏对比"

        public var id: String { rawValue }
        public var icon: String {
            switch self {
            case .sublime: return "doc.plaintext"
            case .split: return "rectangle.split.2x1"
            }
        }
    }
    @State private var editorViewMode: EditorViewMode = .sublime

    // Status and feedback
    @State private var statusMessage: String = "就绪"
    @State private var errorMessage: String? = nil
    @State private var showCopyFeedback: Bool = false
    @State private var lastFormatDurationMs: Double = 0

    // Language selection
    public enum LanguageSelection: String, CaseIterable, Identifiable {
        case auto = "自动检测"
        case sql = "SQL"
        case json = "JSON"
        case xml = "XML / HTML"
        case yaml = "YAML"
        case css = "CSS"
        case markdown = "Markdown"

        public var id: String { rawValue }

        public var targetLanguage: CodeLanguage? {
            switch self {
            case .auto: return nil
            case .sql: return .sql
            case .json: return .json
            case .xml: return .xml
            case .yaml: return .yaml
            case .css: return .css
            case .markdown: return .markdown
            }
        }
    }
    @State private var selectedLanguageOption: LanguageSelection = .auto
    @State private var detectedLanguage: CodeLanguage = .json

    // Formatting options
    @State private var indentStyle: JSONFormatterTool.IndentStyle = .twoSpaces

    // SQL options
    @State private var sqlKeywordCase: SQLFormatOptions.KeywordCase = .uppercase
    @State private var sqlCommaPosition: SQLFormatOptions.CommaPosition = .trailing

    // JSON options
    @State private var jsonSubViewMode: JSONSubViewMode = .code
    @State private var rootNode: JSONTreeNode? = nil
    @State private var showPathBar: Bool = false
    @State private var jsonPathQuery: String = ""
    @State private var showModelExportSheet: Bool = false
    @State private var exportLanguage: JSONFormatterTool.ModelLanguage = .typeScript
    @State private var exportRootName: String = "Root"
    @State private var generatedModelCode: String = ""
    @State private var showModelCopyFeedback: Bool = false

    // Markdown options
    @State private var enablePanguSpacing: Bool = true
    @State private var enableTableAlignment: Bool = true

    // Search & Replace state
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @State private var replaceText: String = ""
    @State private var isFindCaseSensitive: Bool = false
    @State private var findMatchCount: Int = 0
    @State private var currentFindIndex: Int = 0

    public enum JSONSubViewMode: String, CaseIterable {
        case code = "代码视图"
        case tree = "树形折叠"
    }

    public init() {}

    private var effectiveLanguage: CodeLanguage {
        if let explicit = selectedLanguageOption.targetLanguage {
            return explicit
        }
        return detectedLanguage
    }

    private var indentSpaces: String {
        indentStyle == .fourSpaces ? "    " : "  "
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main Top Toolbar
            mainToolbar

            Divider()

            // ⌘F Find & Replace Bar
            if showFindBar {
                FindBarView(
                    findText: $findText,
                    replaceText: $replaceText,
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
                    onReplace: {
                        replaceCurrent()
                    },
                    onReplaceAll: {
                        replaceAll()
                    },
                    onClose: {
                        showFindBar = false
                        findText = ""
                    }
                )
                Divider()
            }

            // Contextual Secondary Toolbar (per language)
            contextualOptionsToolbar

            Divider()

            // JSONPath Filter Bar (when open)
            if effectiveLanguage == .json && showPathBar {
                jsonPathSearchBar
                Divider()
            }

            // Editor Area (Sublime Single Editor or Split Mode)
            Group {
                if editorViewMode == .sublime {
                    sublimeSingleEditor
                } else {
                    splitDiffEditor
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Sublime-style Status Bar at the bottom
            sublimeStatusBar
        }
        .background(
            Button("") {
                showFindBar.toggle()
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        )
        .onChange(of: codeText) { newText in
            updateDetectedLanguage(for: newText)
            validateSyntax(newText)
        }
        .onAppear {
            updateDetectedLanguage(for: codeText)
            validateSyntax(codeText)
        }
        .sheet(isPresented: $showModelExportSheet) {
            modelExportSheetView
        }
    }

    // MARK: - Main Top Toolbar
    private var mainToolbar: some View {
        HStack(spacing: 8) {
            // Prominent Format Button
            Button {
                formatInPlace()
            } label: {
                Label("美化代码", systemImage: "sparkles")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.return, modifiers: .command)
            .help("一键原地格式化代码 (⌘Return)")

            // Minify Button
            if effectiveLanguage != .markdown && effectiveLanguage != .yaml {
                Button {
                    minifyInPlace()
                } label: {
                    Label("压缩", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .controlSize(.regular)
                .help("去除冗余空格与注释，紧凑化代码")
            }

            // Paste & Format Button
            Button {
                pasteAndFormat()
            } label: {
                Label("粘贴并美化", systemImage: "doc.on.clipboard")
            }
            .controlSize(.regular)
            .help("从剪贴板读取并立即执行格式化")

            Divider().frame(height: 18)

            // Language Selector
            Picker("语言", selection: $selectedLanguageOption) {
                ForEach(LanguageSelection.allCases) { item in
                    HStack {
                        if item == .auto {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(item.rawValue)
                    }
                    .tag(item)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)

            if selectedLanguageOption == .auto {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .foregroundColor(.accentColor)
                        .font(.caption2)
                    Text("识别为: \(detectedLanguage.rawValue)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
            }

            Spacer()

            // View Mode Switcher: Sublime Single Editor vs Split View
            Picker("视图", selection: $editorViewMode) {
                ForEach(EditorViewMode.allCases) { vm in
                    Label(vm.rawValue, systemImage: vm.icon).tag(vm)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .help("切换 Sublime Text 单栏直接编辑模式或双栏对比模式")

            Button {
                showFindBar.toggle()
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .controlSize(.small)
            .help("在代码中搜索与替换 (⌘F)")

            Button("清空") {
                beforeText = codeText
                codeText = ""
                rootNode = nil
                statusMessage = "已清空"
                errorMessage = nil
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Contextual Options Toolbar
    private var contextualOptionsToolbar: some View {
        HStack(spacing: 10) {
            switch effectiveLanguage {
            case .sql:
                Picker("关键字", selection: $sqlKeywordCase) {
                    ForEach(SQLFormatOptions.KeywordCase.allCases, id: \.self) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 105)

                Picker("逗号", selection: $sqlCommaPosition) {
                    ForEach(SQLFormatOptions.CommaPosition.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 105)

                Picker("缩进", selection: $indentStyle) {
                    Text("2 空格").tag(JSONFormatterTool.IndentStyle.twoSpaces)
                    Text("4 空格").tag(JSONFormatterTool.IndentStyle.fourSpaces)
                }
                .pickerStyle(.menu)
                .frame(width: 95)

            case .json:
                Picker("缩进", selection: $indentStyle) {
                    ForEach(JSONFormatterTool.IndentStyle.allCases, id: \.self) { ind in
                        Text(ind.rawValue).tag(ind)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                Picker("展示", selection: $jsonSubViewMode) {
                    ForEach(JSONSubViewMode.allCases, id: \.self) { vm in
                        Text(vm.rawValue).tag(vm)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Button {
                    tryRepairJSON()
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
                .help("一键生成 TypeScript 或 Swift 数据模型声明")

                Button {
                    convertToYAML()
                } label: {
                    Label("转为 YAML", systemImage: "doc.text")
                }
                .controlSize(.small)
                .help("将当前 JSON 快速转为 YAML 格式")

            case .xml:
                Picker("缩进", selection: $indentStyle) {
                    Text("2 空格").tag(JSONFormatterTool.IndentStyle.twoSpaces)
                    Text("4 空格").tag(JSONFormatterTool.IndentStyle.fourSpaces)
                }
                .pickerStyle(.menu)
                .frame(width: 95)

            case .yaml:
                Button {
                    convertYAMLToJSON()
                } label: {
                    Label("转为 JSON", systemImage: "curlybraces")
                }
                .controlSize(.small)
                .help("将当前 YAML 转换为标准 JSON")

            case .css:
                Picker("缩进", selection: $indentStyle) {
                    Text("2 空格").tag(JSONFormatterTool.IndentStyle.twoSpaces)
                    Text("4 空格").tag(JSONFormatterTool.IndentStyle.fourSpaces)
                }
                .pickerStyle(.menu)
                .frame(width: 95)

            case .markdown:
                Toggle("盘古之白 (中英文自动空格)", isOn: $enablePanguSpacing)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Toggle("GFM 表格等宽列对齐", isOn: $enableTableAlignment)
                    .toggleStyle(.checkbox)
                    .font(.caption)

            case .plain:
                EmptyView()
            }

            Spacer()

            if editorViewMode == .sublime {
                Text("💡 支持原地直接编辑与 ⌘Z 撤销，和 Sublime Text 一样流畅")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
    }

    // MARK: - JSONPath Search Bar
    private var jsonPathSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .foregroundColor(.accentColor)
                .font(.caption2)

            TextField("JSONPath 路径 (如: features[0] 或 metadata.author)", text: $jsonPathQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .onSubmit {
                    applyJSONPath()
                }

            Button("提取") {
                applyJSONPath()
            }
            .controlSize(.small)

            if !jsonPathQuery.isEmpty {
                Button {
                    jsonPathQuery = ""
                    formatInPlace()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
    }

    // MARK: - Sublime Single Editor (Default Mode)
    private var sublimeSingleEditor: some View {
        Group {
            if effectiveLanguage == .json && jsonSubViewMode == .tree, let root = rootNode {
                VStack(spacing: 0) {
                    HStack {
                        Text("树形结构展示")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    CollapsibleJSONTreeView(rootNode: root)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                MacCodeEditorView(
                    text: $codeText,
                    isEditable: true,
                    language: effectiveLanguage,
                    fontSize: 12,
                    showLineNumbers: true,
                    indentString: indentSpaces,
                    searchQuery: showFindBar ? findText : "",
                    currentMatchIndex: currentFindIndex,
                    isCaseSensitive: isFindCaseSensitive,
                    onFormatAction: {
                        formatInPlace()
                    },
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

    // MARK: - Split Diff Editor (Side by Side Mode)
    private var splitDiffEditor: some View {
        HSplitView {
            // Left: Raw Input / Before
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("原始文本 (Before)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    let count = beforeText.count
                    let lines = beforeText.components(separatedBy: "\n").count
                    Text("\(lines) 行 · \(count) 字符")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                MacCodeEditorView(
                    text: $beforeText,
                    isEditable: true,
                    language: effectiveLanguage,
                    fontSize: 12,
                    showLineNumbers: true,
                    indentString: indentSpaces
                )
            }
            .frame(minWidth: 240, idealWidth: 360, maxWidth: .infinity)

            // Right: Formatted / After
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("格式化结果 (After / Editable)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    let count = codeText.count
                    let lines = codeText.components(separatedBy: "\n").count
                    Text("\(lines) 行 · \(count) 字符")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                MacCodeEditorView(
                    text: $codeText,
                    isEditable: true,
                    language: effectiveLanguage,
                    fontSize: 12,
                    showLineNumbers: true,
                    indentString: indentSpaces,
                    searchQuery: showFindBar ? findText : "",
                    currentMatchIndex: currentFindIndex,
                    isCaseSensitive: isFindCaseSensitive,
                    onFormatAction: {
                        formatInPlace()
                    },
                    onMatchCountChanged: { count in
                        findMatchCount = count
                        if count == 0 {
                            currentFindIndex = 0
                        } else if currentFindIndex >= count {
                            currentFindIndex = max(0, count - 1)
                        }
                    }
                )
            }
            .frame(minWidth: 260, idealWidth: 440, maxWidth: .infinity)
        }
    }

    // MARK: - Sublime Status Bar (Bottom)
    private var sublimeStatusBar: some View {
        HStack(spacing: 12) {
            // Language tag
            HStack(spacing: 4) {
                Image(systemName: effectiveLanguage.icon)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                Text(effectiveLanguage.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12))
            .cornerRadius(4)

            // Syntax status badge
            if let err = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption2)
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Indentation
            Text("缩进: \(indentStyle.rawValue)")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Line & Character stats
            let lineCount = codeText.components(separatedBy: "\n").count
            Text("\(lineCount) 行 · \(codeText.count) 字符")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Copy feedback
            if showCopyFeedback {
                Text("✓ 已复制")
                    .font(.caption2)
                    .foregroundColor(.green)
            }

            Button {
                copyCode()
            } label: {
                Label("复制全部", systemImage: "doc.on.doc")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Core Formatting In-Place Actions
    private func formatInPlace() {
        let rawInput = codeText
        guard !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "文本为空"
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let detected = CodeFormatterTool.detectLanguage(from: rawInput)
        let lang = selectedLanguageOption.targetLanguage ?? detected
        let indentStr = indentSpaces

        var resultText = rawInput
        var err: String? = nil

        switch lang {
        case .json:
            let baseRes = JSONFormatterTool.format(rawInput, mode: .pretty, indent: indentStyle)
            switch baseRes {
            case .success(let formatted):
                resultText = formatted
                if jsonSubViewMode == .tree {
                    rootNode = JSONTreeNode.parse(from: formatted)
                }
            case .failure(let e):
                err = e.localizedDescription
            }

        case .sql:
            let opts = SQLFormatOptions(
                keywordCase: sqlKeywordCase,
                commaPosition: sqlCommaPosition,
                indent: indentStr
            )
            resultText = CodeFormatterTool.formatSQL(rawInput, options: opts)

        case .xml:
            resultText = CodeFormatterTool.formatXML(rawInput, indent: indentStr)

        case .yaml:
            resultText = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)

        case .css:
            resultText = CodeFormatterTool.formatCSS(rawInput, indent: indentStr)

        case .markdown:
            var md = rawInput
            if enablePanguSpacing && enableTableAlignment {
                md = CodeFormatterTool.formatMarkdown(md)
            } else if enablePanguSpacing {
                md = CodeFormatterTool.panguSpacing(md)
            }
            resultText = md

        case .plain:
            resultText = rawInput
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        lastFormatDurationMs = elapsed

        if beforeText.isEmpty {
            beforeText = rawInput
        }

        if err == nil {
            codeText = resultText
            errorMessage = nil
            statusMessage = "格式化完成 (\(String(format: "%.1f", elapsed))ms)"
        } else {
            errorMessage = err
            statusMessage = "语法有误"
        }
    }

    private func minifyInPlace() {
        let rawInput = codeText
        guard !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let detected = CodeFormatterTool.detectLanguage(from: rawInput)
        let lang = selectedLanguageOption.targetLanguage ?? detected

        if beforeText.isEmpty {
            beforeText = rawInput
        }

        switch lang {
        case .json:
            if case .success(let min) = JSONFormatterTool.format(rawInput, mode: .minify, indent: indentStyle) {
                codeText = min
                errorMessage = nil
                statusMessage = "压缩完成"
            }
        case .sql:
            codeText = CodeFormatterTool.minifySQL(rawInput)
            statusMessage = "压缩完成"
        case .xml:
            codeText = CodeFormatterTool.minifyXML(rawInput)
            statusMessage = "压缩完成"
        case .css:
            codeText = CodeFormatterTool.minifyCSS(rawInput)
            statusMessage = "压缩完成"
        default:
            break
        }
    }

    private func pasteAndFormat() {
        if let clip = NSPasteboard.general.string(forType: .string) {
            beforeText = codeText
            codeText = clip
            formatInPlace()
        }
    }

    private func tryRepairJSON() {
        beforeText = codeText
        codeText = JSONFormatterTool.tryRepairJSON(codeText)
        formatInPlace()
    }

    private func convertToYAML() {
        switch CodeFormatterTool.jsonToYAML(codeText) {
        case .success(let yaml):
            beforeText = codeText
            selectedLanguageOption = .yaml
            codeText = yaml
            statusMessage = "已转为 YAML"
            errorMessage = nil
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }

    private func convertYAMLToJSON() {
        switch CodeFormatterTool.yamlToJSON(codeText) {
        case .success(let json):
            beforeText = codeText
            selectedLanguageOption = .json
            codeText = json
            statusMessage = "已转为 JSON"
            errorMessage = nil
            formatInPlace()
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }

    private func applyJSONPath() {
        guard !jsonPathQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            formatInPlace()
            return
        }
        let res = JSONFormatterTool.evaluatePath(codeText, path: jsonPathQuery)
        switch res {
        case .success(let val):
            codeText = val
            statusMessage = "JSONPath 提取成功"
            errorMessage = nil
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }

    private func updateDetectedLanguage(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            detectedLanguage = CodeFormatterTool.detectLanguage(from: trimmed)
        }
    }

    private func validateSyntax(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = nil
            statusMessage = "就绪"
            return
        }

        if effectiveLanguage == .json {
            let res = JSONFormatterTool.format(trimmed, mode: .validate, indent: indentStyle)
            switch res {
            case .success:
                errorMessage = nil
                statusMessage = "语法有效"
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
        }
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codeText, forType: .string)
        withAnimation { showCopyFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopyFeedback = false }
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

            MacCodeEditorView(text: generatedModelCode, isEditable: false, language: .json, fontSize: 12)
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

    private func updateGeneratedModel() {
        let name = exportRootName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Root" : exportRootName
        switch JSONFormatterTool.generateModel(from: codeText, language: exportLanguage, rootName: name) {
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

    private func replaceCurrent() {
        guard !findText.isEmpty, findMatchCount > 0 else { return }
        let options: NSString.CompareOptions = isFindCaseSensitive ? [.literal] : [.caseInsensitive]
        let ns = codeText as NSString
        var searchLoc = 0
        var count = 0
        while searchLoc < ns.length {
            let r = ns.range(of: findText, options: options, range: NSRange(location: searchLoc, length: ns.length - searchLoc))
            if r.location == NSNotFound { break }
            if count == currentFindIndex {
                codeText = ns.replacingCharacters(in: r, with: replaceText)
                break
            }
            count += 1
            searchLoc = r.location + max(1, r.length)
        }
    }

    private func replaceAll() {
        guard !findText.isEmpty, findMatchCount > 0 else { return }
        let options: String.CompareOptions = isFindCaseSensitive ? [.literal] : [.caseInsensitive]
        codeText = codeText.replacingOccurrences(of: findText, with: replaceText, options: options)
    }
}
