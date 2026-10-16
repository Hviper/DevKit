import SwiftUI
import DevKitCore
import AppKit
import UniformTypeIdentifiers

public struct DetectedImageInfo: Equatable {
    public let image: NSImage
    public let width: Int
    public let height: Int
    public let byteSize: Int
    public let format: String

    public static func == (lhs: DetectedImageInfo, rhs: DetectedImageInfo) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height && lhs.byteSize == rhs.byteSize && lhs.format == rhs.format
    }
}

public struct Base64View: View {
    @State private var inputText: String = "Hello DevKit! 轻量好用的 Mac 开发者工具箱"
    @State private var outputText: String = ""
    @State private var operation: CodecOperation = .encode
    @State private var layoutDirection: LayoutDirection = .vertical
    @State private var urlSafe: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showCopyFeedback: Bool = false
    @State private var copyFeedbackText: String = "已复制"

    // Image preview state
    @State private var detectedImage: DetectedImageInfo? = nil
    @State private var previewMode: PreviewMode = .auto

    @State private var conversionTask: Task<Void, Never>? = nil

    // Search state
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @State private var isFindCaseSensitive: Bool = false
    @State private var findMatchCount: Int = 0
    @State private var currentFindIndex: Int = 0

    enum PreviewMode: String, CaseIterable {
        case auto = "智能检测"
        case text = "纯文本"
        case image = "图片预览"
    }

    enum CodecOperation: String, CaseIterable {
        case encode = "Base64 编码"
        case decode = "Base64 解码"
    }

    enum LayoutDirection: String, CaseIterable {
        case vertical = "上下分栏"
        case horizontal = "左右分栏"
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Toolbar
            toolbar

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

            // Draggable Split Area
            if layoutDirection == .vertical {
                VSplitView {
                    inputArea
                        .frame(minHeight: 100, idealHeight: 220, maxHeight: .infinity)

                    outputArea
                        .frame(minHeight: 100, idealHeight: 220, maxHeight: .infinity)
                }
            } else {
                HSplitView {
                    inputArea
                        .frame(minWidth: 200, idealWidth: 350, maxWidth: .infinity)

                    outputArea
                        .frame(minWidth: 200, idealWidth: 350, maxWidth: .infinity)
                }
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
        .onChange(of: inputText) { _ in performConversion() }
        .onChange(of: operation) { _ in performConversion() }
        .onChange(of: urlSafe) { _ in performConversion() }
        .onAppear { performConversion() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("操作", selection: $operation) {
                ForEach(CodecOperation.allCases, id: \.self) { op in
                    Text(op.rawValue).tag(op)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            if operation == .encode {
                Toggle("URL-Safe", isOn: $urlSafe)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .help("用 - 和 _ 替换 + 和 /")

                Button {
                    chooseImageFile()
                } label: {
                    Label("选择图片编码...", systemImage: "photo")
                }
                .controlSize(.small)
                .help("从本地选取图片并转换为 Data URL Base64")
            }

            Button {
                inputText = outputText
                operation = (operation == .encode) ? .decode : .encode
            } label: {
                Label("互换 ⇄", systemImage: "arrow.left.arrow.right")
            }
            .controlSize(.small)
            .help("互换输入与输出，并反转操作")

            Spacer()

            // Layout direction toggle
            Picker("", selection: $layoutDirection) {
                Image(systemName: "rectangle.split.1x2").tag(LayoutDirection.vertical)
                Image(systemName: "rectangle.split.2x1").tag(LayoutDirection.horizontal)
            }
            .pickerStyle(.segmented)
            .frame(width: 70)
            .help("切换分栏方向（上下/左右）")

            Button {
                showFindBar.toggle()
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .controlSize(.small)
            .help("在文本中搜索 (⌘F)")

            Button("清空") {
                inputText = ""
                outputText = ""
                detectedImage = nil
                errorMessage = nil
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(operation == .encode ? "输入待编码文本 / 图片 Data URL" : "输入待解码 Base64 字符串")
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
                    if findMatchCount == 0 {
                        findMatchCount = count
                    }
                }
            )
        }
    }

    private var outputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("输出结果")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text("\(outputText.count) 字符")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))

                if let error = errorMessage {
                    Text("❌ \(error)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                if detectedImage != nil {
                    Picker("", selection: $previewMode) {
                        ForEach(PreviewMode.allCases, id: \.self) { pm in
                            Text(pm.rawValue).tag(pm)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }

                Spacer()

                if showCopyFeedback {
                    Text("✓ \(copyFeedbackText)")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Button {
                    copyOutput()
                } label: {
                    Label("复制文本", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            // Content: Either Image Preview or Text
            if let img = detectedImage, previewMode != .text {
                imagePreviewBox(img)
            } else {
                MacCodeEditorView(
                    text: outputText,
                    isEditable: false,
                    language: .plain,
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
    }

    // MARK: - Image Preview Box
    private func imagePreviewBox(_ info: DetectedImageInfo) -> some View {
        VStack(spacing: 8) {
            // Preview viewport with checkerboard pattern background
            ZStack {
                Color(NSColor.controlBackgroundColor)

                Image(nsImage: info.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

            // Image Meta & Action Bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .foregroundColor(.accentColor)
                    Text("\(info.format) 图片")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("\(info.width) × \(info.height) px")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(formatByteSize(info.byteSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    copyImageToClipboard(info.image)
                } label: {
                    Label("复制图片", systemImage: "photo.on.rectangle")
                }
                .controlSize(.small)

                Button {
                    saveImageToDisk(info.image, format: info.format)
                } label: {
                    Label("保存图片...", systemImage: "square.and.arrow.down")
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .padding(6)
    }

    private func performConversion() {
        conversionTask?.cancel()
        let currentInput = inputText
        let currentOp = operation
        let isUrlSafe = urlSafe

        if currentInput.count < 3000 {
            executeConversion(input: currentInput, op: currentOp, urlSafe: isUrlSafe)
            checkImageDetection(input: currentInput, op: currentOp)
            return
        }

        conversionTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return }

            let (result, error) = await Task.detached(priority: .userInitiated) { () -> (String, String?) in
                switch currentOp {
                case .encode:
                    return (Base64EncoderTool.encodeText(currentInput, urlSafe: isUrlSafe), nil)
                case .decode:
                    switch Base64EncoderTool.decodeText(currentInput) {
                    case .success(let text):
                        return (text, nil)
                    case .failure(let err):
                        return ("", err.localizedDescription)
                    }
                }
            }.value

            if !Task.isCancelled {
                await MainActor.run {
                    self.outputText = result
                    self.errorMessage = error
                    self.checkImageDetection(input: currentInput, op: currentOp)
                }
            }
        }
    }

    private func executeConversion(input: String, op: CodecOperation, urlSafe: Bool) {
        switch op {
        case .encode:
            outputText = Base64EncoderTool.encodeText(input, urlSafe: urlSafe)
            errorMessage = nil
        case .decode:
            switch Base64EncoderTool.decodeText(input) {
            case .success(let text):
                outputText = text
                errorMessage = nil
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
        }
    }

    private func checkImageDetection(input: String, op: CodecOperation) {
        let stringToTest: String
        if op == .decode {
            stringToTest = input
        } else {
            stringToTest = outputText
        }
        self.detectedImage = detectImage(from: stringToTest)
    }

    private func detectImage(from base64OrDataURL: String) -> DetectedImageInfo? {
        var raw = base64OrDataURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        var format = "PNG"
        if raw.hasPrefix("data:image/") {
            if let commaIndex = raw.firstIndex(of: ",") {
                let meta = String(raw[..<commaIndex])
                if meta.contains("png") { format = "PNG" }
                else if meta.contains("jpeg") || meta.contains("jpg") { format = "JPEG" }
                else if meta.contains("gif") { format = "GIF" }
                else if meta.contains("webp") { format = "WebP" }
                else if meta.contains("svg") { format = "SVG" }
                raw = String(raw[raw.index(after: commaIndex)...])
            }
        }

        raw = raw.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: raw, options: .ignoreUnknownCharacters), data.count > 16 else {
            return nil
        }

        guard let nsImage = NSImage(data: data) else { return nil }
        let rep = nsImage.representations.first
        let w = rep?.pixelsWide ?? Int(nsImage.size.width)
        let h = rep?.pixelsHigh ?? Int(nsImage.size.height)
        guard w > 0, h > 0 else { return nil }

        return DetectedImageInfo(
            image: nsImage,
            width: w,
            height: h,
            byteSize: data.count,
            format: format
        )
    }

    private func chooseImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            let ext = url.pathExtension.lowercased()
            let mime = (ext == "jpg" || ext == "jpeg") ? "jpeg" : ext
            let b64 = data.base64EncodedString()
            inputText = "data:image/\(mime);base64,\(b64)"
        }
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        copyFeedbackText = "文本已复制"
        withAnimation { showCopyFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopyFeedback = false }
        }
    }

    private func copyImageToClipboard(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        copyFeedbackText = "图片已复制"
        withAnimation { showCopyFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopyFeedback = false }
        }
    }

    private func saveImageToDisk(_ image: NSImage, format: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "image.\(format.lowercased())"
        if panel.runModal() == .OK, let url = panel.url {
            if let tiff = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let pngData = rep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }
    }

    private func formatByteSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024.0
        return String(format: "%.2f MB", mb)
    }
}
