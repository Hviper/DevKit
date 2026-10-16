import SwiftUI
import DevKitCore

public struct ToolSidebarView: View {
    @EnvironmentObject var appState: AppState
    @FocusState private var isSearchFocused: Bool

    public init() {}

    private var filteredTools: [ToolCategory] {
        if appState.searchText.isEmpty {
            return ToolCategory.allCases
        }
        return ToolCategory.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(appState.searchText)
        }
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索工具 (⌘K)", text: $appState.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let first = filteredTools.first {
                            appState.selectedTool = first
                            appState.searchText = ""
                            isSearchFocused = false
                        }
                    }
                if !appState.searchText.isEmpty {
                    Button {
                        appState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // Tool List
            List(selection: $appState.selectedTool) {
                Section("高频工具箱") {
                    ForEach(filteredTools) { tool in
                        HStack(spacing: 8) {
                            Image(systemName: tool.icon)
                                .frame(width: 18)
                                .foregroundColor(appState.selectedTool == tool ? .accentColor : .primary)
                            Text(tool.rawValue)
                                .font(.system(size: 13))

                            Spacer()

                            Text("⌘\(tool.shortcutNumber)")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .tag(tool)
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .onChange(of: appState.focusSearchTrigger) { _ in
            isSearchFocused = true
        }
    }
}
