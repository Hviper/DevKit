import SwiftUI
import DevKitCore
import AppKit

public struct URLCodecView: View {
    @State private var inputText: String = "https://example.com/search?q=苹果笔记本电脑&category=mac&sort=asc&page=1"
    @State private var outputText: String = ""
    @State private var queryParams: [URLQueryItemInfo] = []
    @State private var mode: URLEncoderTool.EncodeMode = .component
    @State private var operation: CodecOperation = .encode
    @State private var layoutDirection: LayoutDirection = .vertical
    @State private var warningText: String? = nil
    @State private var showCopyFeedback: Bool = false
    @State private var copyBadgeText: String? = nil

    enum CodecOperation: String, CaseIterable {
        case encode = "URL 编码"
        case decode = "URL 解码"
    }

    enum LayoutDirection: String, CaseIterable {
        case vertical = "上下分栏"
        case horizontal = "左右分栏"
    }

    // Search state
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @State private var isFindCaseSensitive: Bool = false
    @State private var findMatchCount: Int = 0
    @State private var currentFindIndex: Int = 0

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

            // Draggable Split Area
            if layoutDirection == .vertical {
                VSplitView {
                    inputArea
                        .frame(minHeight: 90, idealHeight: 180, maxHeight: .infinity)

                    VStack(spacing: 0) {
                        outputArea
                            .frame(minHeight: 90, idealHeight: 180, maxHeight: .infinity)

                        if !queryParams.isEmpty {
                            Divider()
                            queryParamsSection
                                .frame(minHeight: 100, idealHeight: 140, maxHeight: 250)
                        }
                    }
                }
            } else {
                HSplitView {
                    inputArea
                        .frame(minWidth: 200, idealWidth: 350, maxWidth: .infinity)

                    VStack(spacing: 0) {
                        outputArea
                            .frame(minHeight: 120, maxHeight: .infinity)

                        if !queryParams.isEmpty {
                            Divider()
                            queryParamsSection
                                .frame(minHeight: 120, maxHeight: 240)
                        }
                    }
                    .frame(minWidth: 220, idealWidth: 380, maxWidth: .infinity)
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
        .onChange(of: inputText) { _ in performConversion() }
        .onChange(of: mode) { _ in performConversion() }
        .onChange(of: operation) { _ in performConversion() }
        .onAppear { performConversion() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("操作", selection: $operation) {
                ForEach(CodecOperation.allCases, id: \.self) { op in
                    Text(op.rawValue).tag(op)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)

            if operation == .encode {
                Picker("编码范围", selection: $mode) {
                    ForEach(URLEncoderTool.EncodeMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }

            Button {
                inputText = outputText
                operation = (operation == .encode) ? .decode : .encode
            } label: {
                Label("互换 ⇄", systemImage: "arrow.left.arrow.right")
            }
            .controlSize(.small)
            .help("互换输入与输出，并反转操作")

            Spacer()

            // Layout direction toggle
            Picker("", selection: $layoutDirection) {
                Image(systemName: "rectangle.split.1x2").tag(LayoutDirection.vertical)
                Image(systemName: "rectangle.split.2x1").tag(LayoutDirection.horizontal)
            }
            .pickerStyle(.segmented)
            .frame(width: 70)
            .help("切换分栏方向（上下/左右）")

            Button {
                showFindBar.toggle()
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .controlSize(.small)
            .help("在文本中搜索 (⌘F)")

            Button("清空") {
                inputText = ""
                outputText = ""
                queryParams = []
                warningText = nil
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("输入区")
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
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            MacCodeEditorView(
                text: $inputText,
                isEditable: true,
                language: .plain,
                fontSize: 12,
                showLineNumbers: false,
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("转换结果")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text("\(outputText.count) 字符")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))

                if let warning = warningText {
                    Text(warning)
                        .font(.caption2)
                        .foregroundColor(.orange)
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
            .padding(.top, 6)

            MacCodeEditorView(
                text: outputText,
                isEditable: false,
                language: .plain,
                fontSize: 12,
                showLineNumbers: false,
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
        }
    }

    private var queryParamsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.accentColor)
                Text("URL 查询参数拆解 (\(queryParams.count) 个参数)")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                if let b = copyBadgeText {
                    Text("✓ \(b)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            List(queryParams) { item in
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .frame(width: 90, alignment: .leading)

                    Text(item.value)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)

                    Spacer()

                    Button {
                        copySingleParam(item.value, name: item.name)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("复制该参数值")
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    @State private var codecTask: Task<Void, Never>? = nil

    private func performConversion() {
        codecTask?.cancel()
        let currentInput = inputText
        let currentMode = mode
        let currentOp = operation

        if currentInput.count < 3000 {
            executeConversion(input: currentInput, mode: currentMode, op: currentOp)
            return
        }

        codecTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return }

            let (res, warn, params) = await Task.detached(priority: .userInitiated) { () -> (String, String?, [URLQueryItemInfo]) in
                let output: String
                let warning: String?
                switch currentOp {
                case .encode:
                    output = URLEncoderTool.encode(currentInput, mode: currentMode)
                    warning = nil
                case .decode:
                    let (decoded, w) = URLEncoderTool.decode(currentInput)
                    output = decoded
                    warning = w
                }

                let parsed = URLEncoderTool.parseQueryParams(currentInput)
                let finalParams = !parsed.isEmpty ? parsed : URLEncoderTool.parseQueryParams(output)
                return (output, warning, finalParams)
            }.value

            if !Task.isCancelled {
                await MainActor.run {
                    self.outputText = res
                    self.warningText = warn
                    self.queryParams = params
                }
            }
        }
    }

    private func executeConversion(input: String, mode: URLEncoderTool.EncodeMode, op: CodecOperation) {
        switch op {
        case .encode:
            outputText = URLEncoderTool.encode(input, mode: mode)
            warningText = nil
        case .decode:
            let (result, warning) = URLEncoderTool.decode(input)
            outputText = result
            warningText = warning
        }

        let parsed = URLEncoderTool.parseQueryParams(input)
        if !parsed.isEmpty {
            queryParams = parsed
        } else {
            queryParams = URLEncoderTool.parseQueryParams(outputText)
        }
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        withAnimation { showCopyFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopyFeedback = false }
        }
    }

    private func copySingleParam(_ val: String, name: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(val, forType: .string)
        withAnimation { copyBadgeText = "\(name) 已复制" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyBadgeText = nil }
        }
    }
}
