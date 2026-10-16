import SwiftUI
import DevKitCore
import AppKit

public struct HashView: View {
    @State private var inputText: String = "Hello DevKit"
    @State private var secretKey: String = ""
    @State private var isHMACMode: Bool = false
    @State private var uppercase: Bool = false
    @State private var hashResults: [HashResult] = []
    @State private var copyFeedbackText: String? = nil
    @State private var hashTask: Task<Void, Never>? = nil

    // Search state
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @State private var isFindCaseSensitive: Bool = false
    @State private var findMatchCount: Int = 0
    @State private var currentFindIndex: Int = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            toolbar

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

            // HMAC Key Input Bar
            if isHMACMode {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                        .font(.caption2)

                    Text("HMAC 密钥:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("输入用于签名的 Secret Key (例如: my-secret-key)", text: $secretKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))

                    if !secretKey.isEmpty {
                        Button {
                            secretKey = ""
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
                .background(Color.orange.opacity(0.08))
                Divider()
            }

            Divider()

            // Draggable Split between Input text and Result list
            VSplitView {
                // Top: Input text
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("输入待计算的文本")
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
                        language: .plain,
                        fontSize: 12,
                        showLineNumbers: false,
                        searchQuery: showFindBar ? findText : "",
                        currentMatchIndex: currentFindIndex,
                        isCaseSensitive: isFindCaseSensitive,
                        onMatchCountChanged: { count in
                            findMatchCount = count
                        }
                    )
                }
                .frame(minHeight: 80, idealHeight: 140, maxHeight: 300)

                // Bottom: Result list
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(isHMACMode && !secretKey.isEmpty ? "HMAC 签名结果" : "标准哈希结果")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Spacer()

                        if let fb = copyFeedbackText {
                            Text("✓ \(fb)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    List(hashResults) { result in
                        HStack(spacing: 12) {
                            Text(result.isHMAC ? "HMAC-\(result.algorithm.rawValue)" : result.algorithm.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(width: 90, alignment: .leading)
                                .foregroundColor(result.isHMAC ? .orange : .accentColor)

                            Text(result.hash)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)

                            Spacer()

                            Button {
                                let label = (result.isHMAC ? "HMAC-\(result.algorithm.rawValue)" : result.algorithm.rawValue)
                                copy(result.hash, label: "\(label) 已复制")
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .help("复制该哈希值")
                        }
                        .padding(.vertical, 3)
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
        .onChange(of: inputText) { _ in compute() }
        .onChange(of: secretKey) { _ in compute() }
        .onChange(of: isHMACMode) { _ in compute() }
        .onChange(of: uppercase) { _ in compute() }
        .onAppear { compute() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Toggle("大写哈希", isOn: $uppercase)
                .toggleStyle(.checkbox)
                .font(.caption)

            Toggle("HMAC 密钥签名", isOn: $isHMACMode)
                .toggleStyle(.checkbox)
                .font(.caption)

            Button {
                copyAll()
            } label: {
                Label("复制全部哈希", systemImage: "doc.on.doc")
            }
            .controlSize(.small)

            Spacer()

            Button {
                showFindBar.toggle()
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .controlSize(.small)
            .help("在文本中搜索 (⌘F)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func compute() {
        hashTask?.cancel()
        let text = inputText
        let isUpper = uppercase
        let hmac = isHMACMode
        let key = secretKey

        if text.count < 5000 {
            if hmac && !key.isEmpty {
                hashResults = HashGeneratorTool.computeHMAC(for: text, secretKey: key, uppercase: isUpper)
            } else {
                hashResults = HashGeneratorTool.computeHash(for: text, uppercase: isUpper)
            }
            return
        }

        hashTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return }

            let results = await Task.detached(priority: .userInitiated) { () -> [HashResult] in
                if hmac && !key.isEmpty {
                    return HashGeneratorTool.computeHMAC(for: text, secretKey: key, uppercase: isUpper)
                } else {
                    return HashGeneratorTool.computeHash(for: text, uppercase: isUpper)
                }
            }.value

            if !Task.isCancelled {
                await MainActor.run {
                    self.hashResults = results
                }
            }
        }
    }

    private func copy(_ str: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        withAnimation { copyFeedbackText = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyFeedbackText = nil }
        }
    }

    private func copyAll() {
        let content = hashResults.map { "\($0.isHMAC ? "HMAC-" : "")\($0.algorithm.rawValue): \($0.hash)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        withAnimation { copyFeedbackText = "全部哈希已复制" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyFeedbackText = nil }
        }
    }
}
