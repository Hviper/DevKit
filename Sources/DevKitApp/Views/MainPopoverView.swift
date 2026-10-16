import SwiftUI
import DevKitCore

public struct MainPopoverView: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar: Brand, Clipboard Suggestion Banner, Pin, and Window Open
            headerBar

            Divider()

            // Main Content Area: Left Sidebar + Right Tool View
            HSplitView {
                ToolSidebarView()
                    .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)

                toolDetailView
                    .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            Group {
                Button("") { appState.selectedTool = .diff }.keyboardShortcut("1", modifiers: .command)
                Button("") { appState.selectedTool = .url }.keyboardShortcut("2", modifiers: .command)
                Button("") { appState.selectedTool = .base64 }.keyboardShortcut("3", modifiers: .command)
                Button("") { appState.selectedTool = .hash }.keyboardShortcut("4", modifiers: .command)
                Button("") { appState.selectedTool = .json }.keyboardShortcut("5", modifiers: .command)
                Button("") { appState.selectedTool = .uuid }.keyboardShortcut("6", modifiers: .command)
                Button("") { appState.selectedTool = .timestamp }.keyboardShortcut("7", modifiers: .command)
                Button("") { appState.selectedTool = .regex }.keyboardShortcut("8", modifiers: .command)
                Button("") { appState.selectedTool = .jwt }.keyboardShortcut("9", modifiers: .command)
                Button("") { appState.focusSearchTrigger.toggle() }.keyboardShortcut("k", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
        .onAppear {
            appState.onPopoverOpened()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .foregroundColor(.accentColor)
                Text("DevKit")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            if let suggestion = appState.clipboardSuggestion {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                    Text("\(suggestion.matchedDescription)")
                        .font(.caption)
                        .lineLimit(1)
                    Button("使用 \(suggestion.suggestedTool.rawValue)") {
                        appState.applySuggestion(suggestion)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        appState.dismissSuggestion()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }

            Spacer()

            // Pin Button
            Button {
                appState.togglePin()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: appState.isPinned ? "pin.fill" : "pin")
                        .foregroundColor(appState.isPinned ? .accentColor : .secondary)
                    Text(appState.isPinned ? "已钉住" : "钉住")
                        .font(.caption)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(appState.isPinned ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("p", modifiers: .command)
            .help("钉住窗口，失焦不收起 (⌘P)")

            Divider()
                .frame(height: 16)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("退出 DevKit")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var toolDetailView: some View {
        ZStack {
            toolWrapper(.diff) { DiffView() }
            toolWrapper(.url) { URLCodecView() }
            toolWrapper(.base64) { Base64View() }
            toolWrapper(.hash) { HashView() }
            toolWrapper(.json) { CodeFormatterView() }
            toolWrapper(.uuid) { UUIDView() }
            toolWrapper(.timestamp) { TimestampView() }
            toolWrapper(.regex) { RegexView() }
            toolWrapper(.jwt) { JWTView() }
        }
    }

    @ViewBuilder
    private func toolWrapper<Content: View>(_ tool: ToolCategory, @ViewBuilder content: () -> Content) -> some View {
        let isSelected = appState.selectedTool == tool
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .zIndex(isSelected ? 1 : 0)
    }
}
