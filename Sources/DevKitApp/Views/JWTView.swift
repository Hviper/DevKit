import SwiftUI
import DevKitCore
import AppKit

public struct JWTView: View {
    @State private var tokenString: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE5OTk5OTk5OTl9.4flK7N8qL_7Xv9"
    @State private var tokenInfo: JWTTokenInfo? = nil
    @State private var headerNode: JSONTreeNode? = nil
    @State private var payloadNode: JSONTreeNode? = nil
    @State private var displayMode: JSONViewDisplayMode = .tree
    @State private var errorMessage: String? = nil
    @State private var copyFeedbackText: String? = nil

    // Search state
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @State private var isFindCaseSensitive: Bool = false
    @State private var findMatchCount: Int = 0
    @State private var currentFindIndex: Int = 0

    enum JSONViewDisplayMode: String, CaseIterable {
        case tree = "树形折叠"
        case code = "高亮代码"
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Info Bar
            topBar

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

            // Draggable Vertical Split between Token Input and Decoded JSON
            VSplitView {
                // Top: Token Input Area
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("粘贴 JWT Token")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("从剪贴板粘贴") {
                            if let clip = NSPasteboard.general.string(forType: .string) {
                                tokenString = clip
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.accentColor)

                        Button("清空") {
                            tokenString = ""
                            tokenInfo = nil
                            headerNode = nil
                            payloadNode = nil
                            errorMessage = nil
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    MacCodeEditorView(
                        text: $tokenString,
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
                .frame(minHeight: 70, idealHeight: 100, maxHeight: 200)

                // Bottom: Decoded Header and Payload Split (HSplitView)
                HSplitView {
                    // Header Box
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Header (头部元数据)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("复制") {
                                copy(tokenInfo?.headerJSON ?? "", label: "Header 已复制")
                            }
                            .buttonStyle(.plain)
                            .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)

                        if displayMode == .tree && headerNode != nil {
                            CollapsibleJSONTreeView(rootNode: headerNode)
                        } else {
                            MacCodeEditorView(
                                text: tokenInfo?.headerJSON ?? "{}",
                                isEditable: false,
                                language: .json,
                                fontSize: 12,
                                showLineNumbers: false,
                                searchQuery: showFindBar ? findText : "",
                                currentMatchIndex: currentFindIndex,
                                isCaseSensitive: isFindCaseSensitive
                            )
                        }
                    }
                    .frame(minWidth: 180, idealWidth: 320, maxWidth: .infinity)

                    // Payload Box
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Payload (声明数据 Claims)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("复制") {
                                copy(tokenInfo?.payloadJSON ?? "", label: "Payload 已复制")
                            }
                            .buttonStyle(.plain)
                            .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)

                        if displayMode == .tree && payloadNode != nil {
                            CollapsibleJSONTreeView(rootNode: payloadNode)
                        } else {
                            MacCodeEditorView(
                                text: tokenInfo?.payloadJSON ?? "{}",
                                isEditable: false,
                                language: .json,
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
                    .frame(minWidth: 200, idealWidth: 420, maxWidth: .infinity)
                }
                .frame(minHeight: 180, maxHeight: .infinity)
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
        .onChange(of: tokenString) { _ in decodeToken() }
        .onChange(of: displayMode) { mode in
            if mode == .tree, let info = tokenInfo {
                if headerNode == nil { headerNode = JSONTreeNode.parse(from: info.headerJSON) }
                if payloadNode == nil { payloadNode = JSONTreeNode.parse(from: info.payloadJSON) }
            }
        }
        .onAppear { decodeToken() }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            if let info = tokenInfo {
                Text(info.statusMessage)
                    .font(.caption)
                    .fontWeight(.semibold)
            } else if let err = errorMessage {
                Text("❌ \(err)")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            Button {
                showFindBar.toggle()
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .controlSize(.small)
            .help("在 Token、Header 与 Payload 中搜索 (⌘F)")

            Picker("视图", selection: $displayMode) {
                ForEach(JSONViewDisplayMode.allCases, id: \.self) { vm in
                    Text(vm.rawValue).tag(vm)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            if let feedback = copyFeedbackText {
                Text("✓ \(feedback)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func decodeToken() {
        guard !tokenString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            tokenInfo = nil
            headerNode = nil
            payloadNode = nil
            errorMessage = nil
            return
        }

        switch JWTDecoderTool.decode(tokenString) {
        case .success(let info):
            tokenInfo = info
            if displayMode == .tree {
                headerNode = JSONTreeNode.parse(from: info.headerJSON)
                payloadNode = JSONTreeNode.parse(from: info.payloadJSON)
            } else {
                headerNode = nil
                payloadNode = nil
            }
            errorMessage = nil
        case .failure(let err):
            tokenInfo = nil
            headerNode = nil
            payloadNode = nil
            errorMessage = err.localizedDescription
        }
    }

    private func copy(_ text: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation { copyFeedbackText = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyFeedbackText = nil }
        }
    }
}
