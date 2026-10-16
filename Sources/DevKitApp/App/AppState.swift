import SwiftUI
import DevKitCore
import AppKit

@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedTool: ToolCategory = .diff
    @Published public var searchText: String = ""
    @Published public var isPinned: Bool = false
    @Published public var clipboardSuggestion: ClipboardDetectionResult? = nil
    @Published public var focusSearchTrigger: Bool = false

    public init() {}

    public func onPopoverOpened() {
        // Read clipboard strictly on-demand (no background polling)
        if let string = NSPasteboard.general.string(forType: .string) {
            self.clipboardSuggestion = ClipboardDetector.detect(content: string)
        } else {
            self.clipboardSuggestion = nil
        }
    }

    public func applySuggestion(_ suggestion: ClipboardDetectionResult) {
        self.selectedTool = suggestion.suggestedTool
        self.clipboardSuggestion = nil
    }

    public func dismissSuggestion() {
        self.clipboardSuggestion = nil
    }

    public func togglePin() {
        self.isPinned.toggle()
        for window in NSApp.windows {
            window.level = self.isPinned ? .floating : .normal
        }
    }
}
