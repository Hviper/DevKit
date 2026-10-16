import SwiftUI
import DevKitCore
import AppKit

public struct RegexView: View {
    @State private var pattern: String = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
    @State private var testText: String = "Contact us at support@example.com or feedback@devkit.io for any questions!"
    @State private var caseInsensitive: Bool = true
    @State private var multiline: Bool = false
    @State private var output: RegexTestOutput = .empty
    @State private var viewMode: TestViewMode = .edit
    @State private var copyFeedbackText: String? = nil
    @State private var testTask: Task<Void, Never>? = nil

    // Search state
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @State private var isFindCaseSensitive: Bool = false
    @State private var findMatchCount: Int = 0
    @State private var currentFindIndex: Int = 0

    enum TestViewMode: String, CaseIterable {
        case edit = "编辑文本"
        case highlight = "行内高亮"
    }

    public init() {}

    @State private var cachedHighlightedText: AttributedString = AttributedString("")

    public var body: some View {
        VStack(spacing: 0) {
            // Pattern input bar & Templates
            patternBar

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

            // Draggable Split between Test Text and Match Results
            VSplitView {
                // Top: Test Text Editor / Highlighted Preview
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("测试文本")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Text("\(testText.count) 字符")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))

                        Picker("", selection: $viewMode) {
                            ForEach(TestViewMode.allCases, id: \.self) { vm in
                                Text(vm.rawValue).tag(vm)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)

                        Spacer()

                        Button("从剪贴板粘贴") {
                            if let clip = NSPasteboard.general.string(forType: .string) {
                                testText = clip
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.accentColor)

                        Button("清空") {
                            testText = ""
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    if viewMode == .edit {
                        MacCodeEditorView(
                            text: $testText,
                            isEditable: true,
                            language: .plain,
                            fontSize: 12,
                            showLineNumbers: true,
                            searchQuery: showFindBar ? findText : "",
                            currentMatchIndex: currentFindIndex,
                            isCaseSensitive: isFindCaseSensitive,
                            onMatchCountChanged: { count in
                                findMatchCount = count
                            }
                        )
                    } else {
                        ScrollView(.vertical) {
                            Text(cachedHighlightedText)
                                .textSelection(.enabled)
                                .lineSpacing(3)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .background(Color(NSColor.textBackgroundColor))
                    }
                }
                .frame(minHeight: 90, idealHeight: 160, maxHeight: 350)

                // Bottom: Matches List
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("匹配结果 (\(output.totalCount) 处匹配)")
                            .font(.caption)
                            .fontWeight(.semibold)

                        if let err = output.error {
                            Text(err)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }

                        Spacer()

                        if let fb = copyFeedbackText {
                            Text("✓ \(fb)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    List(output.matches) { match in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(match.matchIndex)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                                Text(match.fullMatch)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                Spacer()
                                Text("位置: [\(match.range.location), \(match.range.length)]")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Button {
                                    copy(match.fullMatch)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.plain)
                            }

                            if !match.captureGroups.isEmpty {
                                HStack {
                                    Text("捕获组:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    ForEach(Array(match.captureGroups.enumerated()), id: \.offset) { idx, group in
                                        Text("$\(idx + 1): \(group)")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.1))
                                            .cornerRadius(3)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.inset)
                }
                .frame(minHeight: 120, maxHeight: .infinity)
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
        .onChange(of: pattern) { _ in scheduleTest() }
        .onChange(of: testText) { _ in scheduleTest() }
        .onChange(of: caseInsensitive) { _ in scheduleTest() }
        .onChange(of: multiline) { _ in scheduleTest() }
        .onAppear { scheduleTest() }
    }

    private var patternBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("正则:")
                    .font(.caption)
                    .fontWeight(.semibold)

                TextField("输入正则表达式，如 \\d+", text: $pattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Toggle("大小写 (i)", isOn: $caseInsensitive)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Toggle("多行 (m)", isOn: $multiline)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Button {
                    showFindBar.toggle()
                } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .controlSize(.small)
                .help("在文本中搜索 (⌘F)")
            }

            HStack {
                Text("常用模板:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Button("邮箱地址") {
                    pattern = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
                }
                .buttonStyle(.plain)
                .font(.caption2)

                Button("IPv4 地址") {
                    pattern = #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#
                }
                .buttonStyle(.plain)
                .font(.caption2)

                Button("URL 链接") {
                    pattern = #"https?:\/\/[^\s]+"#
                }
                .buttonStyle(.plain)
                .font(.caption2)

                Button("中国手机号") {
                    pattern = #"1[3-9]\d{9}"#
                }
                .buttonStyle(.plain)
                .font(.caption2)
            }
        }
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func scheduleTest() {
        testTask?.cancel()
        testTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return }

            let flags = RegexTesterTool.Flags(
                caseInsensitive: caseInsensitive,
                multiline: multiline,
                dotMatchesLineSeparators: false
            )

            let result = await RegexTesterTool.test(pattern: pattern, text: testText, flags: flags)
            if Task.isCancelled { return }

            let limitedMatches = Array(result.matches.prefix(500))
            let ns = testText as NSString
            let mutAttr = NSMutableAttributedString(
                string: testText,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor.textColor
                ]
            )
            for match in limitedMatches {
                if match.range.location + match.range.length <= ns.length {
                    mutAttr.addAttributes([
                        .backgroundColor: NSColor.systemYellow.withAlphaComponent(0.35),
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
                    ], range: match.range)
                }
            }
            let attr = (try? AttributedString(mutAttr, including: \.appKit)) ?? AttributedString(testText)

            if !Task.isCancelled {
                await MainActor.run {
                    self.output = result
                    self.cachedHighlightedText = attr
                }
            }
        }
    }

    private func copy(_ str: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        withAnimation { copyFeedbackText = "已复制" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyFeedbackText = nil }
        }
    }
}
