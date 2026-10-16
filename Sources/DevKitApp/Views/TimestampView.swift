import SwiftUI
import DevKitCore
import AppKit

public struct TimestampView: View {
    @State private var currentResult: TimestampConversionResult = TimestampConverterTool.current()
    
    // Timestamp to Date state
    @State private var inputTimestamp: String = "\(Int64(Date().timeIntervalSince1970))"
    @State private var convertedFromTimestamp: TimestampConversionResult? = nil
    
    // Date Picker state
    @State private var selectedDate: Date = Date()
    @State private var inputDateString: String = ""
    @State private var convertedFromDate: TimestampConversionResult = TimestampConverterTool.convert(date: Date())
    
    // Feedback
    @State private var copyFeedbackText: String? = nil

    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: Real-time current clock
                realtimeClockSection

                // Section 2: Visual Date & Time Picker -> Timestamp (选定时间核心能力)
                datePickerSection

                // Section 3: Timestamp -> Date (时间戳反查日期)
                timestampToDateSection
            }
            .padding(14)
        }
        .onReceive(timer) { _ in
            currentResult = TimestampConverterTool.current()
        }
        .onAppear {
            syncSelectedDate(Date())
            convertTimestamp()
        }
    }

    // MARK: - Section 1: Realtime Clock
    private var realtimeClockSection: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .foregroundColor(.accentColor)
                        Text("当前实时时间戳")
                            .font(.headline)
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("秒级:")
                                .foregroundColor(.secondary)
                            Text("\(currentResult.seconds)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                            Button {
                                copy("\(currentResult.seconds)", label: "当前秒级时间戳已复制")
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().frame(height: 14)

                        HStack(spacing: 4) {
                            Text("毫秒:")
                                .foregroundColor(.secondary)
                            Text("\(currentResult.milliseconds)")
                                .font(.system(.body, design: .monospaced))
                            Button {
                                copy("\(currentResult.milliseconds)", label: "当前毫秒时间戳已复制")
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(currentResult.localFormatted)
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.monospaced)
                    Text("UTC: \(currentResult.utcFormatted)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
        }
    }

    // MARK: - Section 2: Date Picker -> Timestamp (图形化选定时间)
    private var datePickerSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.orange)
                        Text("选定时间 → 转换为时间戳")
                            .font(.headline)
                    }

                    Spacer()

                    if let fb = copyFeedbackText {
                        Text("✓ \(fb)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                // Quick presets buttons
                HStack(spacing: 6) {
                    Text("快捷设定:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("现在") {
                        syncSelectedDate(Date())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("今天 00:00") {
                        let cal = Calendar.current
                        let start = cal.startOfDay(for: Date())
                        syncSelectedDate(start)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("今天 23:59") {
                        let cal = Calendar.current
                        let start = cal.startOfDay(for: Date())
                        if let end = cal.date(byAdding: .init(hour: 23, minute: 59, second: 59), to: start) {
                            syncSelectedDate(end)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("+1 小时") {
                        syncSelectedDate(selectedDate.addingTimeInterval(3600))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("+1 天") {
                        syncSelectedDate(selectedDate.addingTimeInterval(86400))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("+7 天") {
                        syncSelectedDate(selectedDate.addingTimeInterval(86400 * 7))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                // Visual Date & Time Pickers
                HStack(spacing: 16) {
                    // Graphical Date and Time Picker
                    DatePicker(
                        "选定日期时间:",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: selectedDate) { newDate in
                        updateFromPicker(newDate)
                    }

                    // Direct text input sync
                    HStack(spacing: 6) {
                        Text("或手动编辑:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("yyyy-MM-dd HH:mm:ss", text: $inputDateString)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 190)
                            .onSubmit {
                                if case .success(let res) = TimestampConverterTool.parseDate(dateString: inputDateString) {
                                    selectedDate = Date(timeIntervalSince1970: Double(res.seconds))
                                    convertedFromDate = res
                                }
                            }
                    }
                }

                Divider()

                // Result Timestamp Display
                VStack(spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("10 位秒级时间戳 (Unix Timestamp):")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(convertedFromDate.seconds)")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                        }

                        Spacer()

                        Button {
                            copy("\(convertedFromDate.seconds)", label: "秒级时间戳已复制")
                        } label: {
                            Label("复制秒级", systemImage: "doc.on.doc")
                        }
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("13 位毫秒时间戳 (JavaScript / Java):")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(convertedFromDate.milliseconds)")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                        }

                        Spacer()

                        Button {
                            copy("\(convertedFromDate.milliseconds)", label: "毫秒时间戳已复制")
                        } label: {
                            Label("复制毫秒", systemImage: "doc.on.doc")
                        }
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
            }
            .padding(10)
        }
    }

    // MARK: - Section 3: Timestamp -> Date
    private var timestampToDateSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "number.circle")
                        .foregroundColor(.green)
                    Text("时间戳 → 日期")
                        .font(.headline)

                    Spacer()

                    Button("粘贴剪贴板") {
                        if let clip = NSPasteboard.general.string(forType: .string) {
                            inputTimestamp = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                            convertTimestamp()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(.accentColor)

                    Button("使用当前时间戳") {
                        inputTimestamp = "\(Int64(Date().timeIntervalSince1970))"
                        convertTimestamp()
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                }

                HStack {
                    TextField("输入 10 位秒级或 13 位毫秒时间戳", text: $inputTimestamp)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: inputTimestamp) { _ in
                            convertTimestamp()
                        }
                }

                if let res = convertedFromTimestamp {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(res.isDetectedMilliseconds ? "⚡ 自动识别为 13 位毫秒时间戳" : "⚡ 自动识别为 10 位秒级时间戳")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                                .fontWeight(.medium)

                            Spacer()

                            Text("相对时间: \(res.relativeFormatted)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 2)

                        Divider()

                        HStack {
                            Text("本地时间:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .leading)
                            Text(res.localFormatted)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                            Spacer()
                            Button("复制") { copy(res.localFormatted, label: "本地时间已复制") }
                                .controlSize(.mini)
                        }

                        HStack {
                            Text("北京时间 (GMT+8):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)
                            Text(res.beijingFormatted)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("复制") { copy(res.beijingFormatted, label: "北京时间已复制") }
                                .controlSize(.mini)
                        }

                        HStack {
                            Text("纽约时间 (EST):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)
                            Text(res.newYorkFormatted)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("复制") { copy(res.newYorkFormatted, label: "纽约时间已复制") }
                                .controlSize(.mini)
                        }

                        HStack {
                            Text("UTC 时间:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .leading)
                            Text(res.utcFormatted)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("复制") { copy(res.utcFormatted, label: "UTC 时间已复制") }
                                .controlSize(.mini)
                        }

                        HStack {
                            Text("ISO 8601:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .leading)
                            Text(res.iso8601)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("复制") { copy(res.iso8601, label: "ISO 8601 已复制") }
                                .controlSize(.mini)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
            }
            .padding(10)
        }
    }

    // MARK: - Helpers
    private func syncSelectedDate(_ date: Date) {
        selectedDate = date
        convertedFromDate = TimestampConverterTool.convert(date: date)
        inputDateString = convertedFromDate.localFormatted
    }

    private func updateFromPicker(_ date: Date) {
        convertedFromDate = TimestampConverterTool.convert(date: date)
        inputDateString = convertedFromDate.localFormatted
    }

    private func convertTimestamp() {
        if case .success(let res) = TimestampConverterTool.convert(timestampString: inputTimestamp) {
            convertedFromTimestamp = res
        } else {
            convertedFromTimestamp = nil
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
}
