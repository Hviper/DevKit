import SwiftUI
import DevKitCore
import AppKit

public struct CollapsibleJSONTreeView: View {
    let rootNode: JSONTreeNode?
    @State private var copyBadge: String? = nil

    public init(rootNode: JSONTreeNode?) {
        self.rootNode = rootNode
    }

    public var body: some View {
        // Tree ScrollView - Vertical only to pin strictly to top (prevents 2D ScrollView centering bug)
        ScrollView(.vertical) {
            if let root = rootNode {
                VStack(alignment: .leading, spacing: 2) {
                    // If root is an object or array, directly render its top-level children
                    // to avoid an awkward empty root row floating in space
                    if let children = root.children, !children.isEmpty {
                        ForEach(children) { child in
                            JSONNodeRowView(node: child, indentLevel: 0) { val, label in
                                copyValue(val, label: label)
                            }
                        }
                    } else {
                        JSONNodeRowView(node: root, indentLevel: 0) { val, label in
                            copyValue(val, label: label)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "curlybraces")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("无有效 JSON 数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
        .overlay(alignment: .topTrailing) {
            if let badge = copyBadge {
                Text("✓ \(badge)")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                    .cornerRadius(4)
                    .padding(8)
                    .transition(.opacity)
            }
        }
    }

    private func copyValue(_ val: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(val, forType: .string)
        withAnimation { copyBadge = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copyBadge = nil }
        }
    }
}

struct JSONNodeRowView: View {
    @ObservedObject var node: JSONTreeNode
    let indentLevel: Int
    let onCopy: (String, String) -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .center, spacing: 4) {
                // Indentation Guide Lines
                if indentLevel > 0 {
                    HStack(spacing: 12) {
                        ForEach(0..<indentLevel, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.secondary.opacity(0.18))
                                .frame(width: 1, height: 16)
                        }
                    }
                    .padding(.leading, 2)
                    .padding(.trailing, 4)
                }

                // Disclosure Button (only for Object or Array)
                if node.type == .object || node.type == .array {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            node.isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 16)
                }

                // Key Name
                if let key = node.key {
                    Text("\"\(key)\":")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(NSColor.systemBlue))
                }

                // Value or Summary Badge
                if node.type == .object || node.type == .array {
                    Text(node.summary)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                } else {
                    valueView(for: node)
                }

                // Copy button on hover (clean & subtle, not permanently polluting the view)
                if isHovered, let valStr = stringForCopy(node) {
                    Button {
                        onCopy(valStr, "已复制")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .help("复制该值")
                    .transition(.opacity)
                }

                Spacer(minLength: 8)
            }
            .frame(height: 22)
            .padding(.horizontal, 4)
            .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            .cornerRadius(4)
            .onHover { hovering in
                isHovered = hovering
            }

            // Render Children if Expanded
            if (node.type == .object || node.type == .array) && node.isExpanded {
                if let children = node.children {
                    ForEach(children) { child in
                        JSONNodeRowView(node: child, indentLevel: indentLevel + 1, onCopy: onCopy)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func valueView(for node: JSONTreeNode) -> some View {
        switch node.type {
        case .string:
            Text("\"\(node.value as? String ?? "")\"")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(NSColor.systemGreen))
        case .number:
            Text(node.summary)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(NSColor.systemPurple))
        case .boolean:
            Text(node.summary)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(NSColor.systemOrange))
        case .null:
            Text("null")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
        default:
            EmptyView()
        }
    }

    private func stringForCopy(_ node: JSONTreeNode) -> String? {
        switch node.type {
        case .string:
            return node.value as? String
        case .number, .boolean:
            return "\(node.value ?? "")"
        case .null:
            return "null"
        default:
            return nil
        }
    }
}
