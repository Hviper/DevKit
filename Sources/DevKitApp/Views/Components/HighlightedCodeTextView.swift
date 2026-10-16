import SwiftUI
import DevKitCore
import AppKit

public struct HighlightedCodeTextView: View {
    let jsonString: String
    let fontSize: CGFloat

    public init(jsonString: String, fontSize: CGFloat = 12) {
        self.jsonString = jsonString
        self.fontSize = fontSize
    }

    public var body: some View {
        MacCodeEditorView(text: jsonString, fontSize: fontSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
