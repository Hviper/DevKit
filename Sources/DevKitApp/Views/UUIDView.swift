import SwiftUI
import DevKitCore
import AppKit

public struct UUIDView: View {
    @State private var count: Int = 5
    @State private var format: UUIDGeneratorTool.FormatOption = .standard
    @State private var results: [String] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Stepper("数量: \(count)", value: $count, in: 1...100)
                    .frame(width: 140)

                Picker("格式", selection: $format) {
                    ForEach(UUIDGeneratorTool.FormatOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)

                Button {
                    generate()
                } label: {
                    Label("重新生成", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button {
                    copyAll()
                } label: {
                    Label("复制全部", systemImage: "doc.on.doc")
                }
            }
            .padding(10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            List(results, id: \.self) { uuid in
                HStack {
                    Text(uuid)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        copy(uuid)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("复制此 UUID")
                }
                .padding(.vertical, 3)
            }
            .listStyle(.inset)
        }
        .onChange(of: count) { _ in generate() }
        .onChange(of: format) { _ in generate() }
        .onAppear { generate() }
    }

    private func generate() {
        results = UUIDGeneratorTool.generate(count: count, format: format)
    }

    private func copy(_ str: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
    }

    private func copyAll() {
        let content = results.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
}
