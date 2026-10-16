import SwiftUI
import AppKit

public struct FindBarView: View {
    @Binding var findText: String
    var replaceText: Binding<String>?
    @Binding var isCaseSensitive: Bool
    let matchCount: Int
    let currentMatchIndex: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    var onReplace: (() -> Void)?
    var onReplaceAll: (() -> Void)?
    let onClose: () -> Void

    @FocusState private var isFindFocused: Bool
    @State private var showReplaceRow: Bool = false

    public init(
        findText: Binding<String>,
        replaceText: Binding<String>? = nil,
        isCaseSensitive: Binding<Bool>,
        matchCount: Int,
        currentMatchIndex: Int,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onReplace: (() -> Void)? = nil,
        onReplaceAll: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self._findText = findText
        self.replaceText = replaceText
        self._isCaseSensitive = isCaseSensitive
        self.matchCount = matchCount
        self.currentMatchIndex = currentMatchIndex
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onReplace = onReplace
        self.onReplaceAll = onReplaceAll
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 4) {
            // Main Search Row
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)

                TextField("在当前内容中搜索... (Enter 下一个 / Shift+Enter 上一个)", text: $findText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .focused($isFindFocused)
                    .onSubmit {
                        if NSEvent.modifierFlags.contains(.shift) {
                            onPrevious()
                        } else {
                            onNext()
                        }
                    }

                if !findText.isEmpty {
                    if matchCount == 0 {
                        Text("无匹配")
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else {
                        Text("\(currentMatchIndex + 1)/\(matchCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    Button {
                        onPrevious()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)
                    .help("上一个匹配项 (Shift+Enter / ⌥↑)")

                    Button {
                        onNext()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)
                    .help("下一个匹配项 (Enter / ⌥↓)")
                }

                // Case Sensitivity Toggle
                Button {
                    isCaseSensitive.toggle()
                } label: {
                    Text("Aa")
                        .font(.caption)
                        .fontWeight(isCaseSensitive ? .bold : .regular)
                        .foregroundColor(isCaseSensitive ? .accentColor : .secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isCaseSensitive ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help("区分大小写")

                // Expand Replace Toggle if replace is supported
                if replaceText != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showReplaceRow.toggle()
                        }
                    } label: {
                        Image(systemName: showReplaceRow ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(showReplaceRow ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("展开/收起替换栏")
                }

                // Close Button
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("关闭搜索 (Esc)")
            }

            // Optional Replace Row
            if showReplaceRow, let replaceBinding = replaceText {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                        .font(.caption2)

                    TextField("替换为...", text: replaceBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit {
                            onReplace?()
                        }

                    Button("替换") {
                        onReplace?()
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlColor))
                    .cornerRadius(3)
                    .disabled(findText.isEmpty || matchCount == 0)

                    Button("全部替换") {
                        onReplaceAll?()
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlColor))
                    .cornerRadius(3)
                    .disabled(findText.isEmpty || matchCount == 0)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFindFocused = true
            }
        }
    }
}
