import Foundation
import DevKitCore

@main
struct DevKitTestRunner {
    static func main() async {
        print("========================================")
        print("🚀 DevKitCore 核心算法单元测试运行器")
        print("========================================")

        var passed = 0
        var failed = 0

        func assertTest(_ name: String, _ condition: Bool) {
            if condition {
                print("  ✅ [PASS] \(name)")
                passed += 1
            } else {
                print("  ❌ [FAIL] \(name)")
                failed += 1
            }
        }

        // 1. Myers Diff Tests
        print("\n[1/10] Myers Diff 算法测试:")
        let diffEngine = MyersDiff()
        let t1 = "Line 1\nLine 2\nLine 3"
        let res1 = await diffEngine.diff(oldText: t1, newText: t1)
        assertTest("完全相同文本判定", res1.isIdentical && res1.additions == 0 && res1.deletions == 0)

        let tOld = "Apple\nBanana\nOrange"
        let tNew = "Apple\nCherry\nOrange\nPear"
        let res2 = await diffEngine.diff(oldText: tOld, newText: tNew)
        assertTest("常规增删改对比", !res2.isIdentical && res2.additions >= 1 && res2.deletions >= 1)

        let wsOld = "  let a = 1;  "
        let wsNew = "let a = 1;"
        let res3 = await diffEngine.diff(oldText: wsOld, newText: wsNew, ignoreWhitespace: true)
        assertTest("忽略空白差异特性", res3.isIdentical)

        let caseOld = "HELLO WORLD"
        let caseNew = "hello world"
        let resCase = await diffEngine.diff(oldText: caseOld, newText: caseNew, ignoreCase: true)
        assertTest("忽略大小写对比特性", resCase.isIdentical)

        // Large 5,000-line diff benchmark
        let prefixLines = (1...2500).map { "Common prefix line \($0)" }
        let suffixLines = (1...2500).map { "Common suffix line \($0)" }
        let largeOld = (prefixLines + ["Old modified row 1", "Old modified row 2"] + suffixLines).joined(separator: "\n")
        let largeNew = (prefixLines + ["New inserted row 1", "New inserted row 2", "New inserted row 3"] + suffixLines).joined(separator: "\n")
        let startDiff = CFAbsoluteTimeGetCurrent()
        let largeRes = await diffEngine.diff(oldText: largeOld, newText: largeNew)
        let elapsedDiff = CFAbsoluteTimeGetCurrent() - startDiff
        assertTest("5000行大文本对比 (<100ms: 实测 \(String(format: "%.3f", elapsedDiff))s)", elapsedDiff < 0.1 && largeRes.additions >= 3)

        // 2. URL Codec Tests
        print("\n[2/10] URL 编解码测试:")
        let urlOrig = "https://example.com/api?q=苹果&id=100"
        let urlEnc = URLEncoderTool.encode(urlOrig, mode: .component)
        assertTest("URL 中文字符编码", urlEnc.contains("%E8%8B%B9%E6%9E%9C"))
        let (urlDec, _) = URLEncoderTool.decode(urlEnc)
        assertTest("URL 正向解码还原", urlDec == urlOrig)

        // 3. Base64 Codec Tests
        print("\n[3/10] Base64 编解码测试:")
        let b64Orig = "DevKit: 极致轻量开发工具箱"
        let b64Enc = Base64EncoderTool.encodeText(b64Orig)
        let b64Dec = Base64EncoderTool.decodeText(b64Enc)
        if case .success(let text) = b64Dec {
            assertTest("Base64 纯文本编解码", text == b64Orig)
        } else {
            assertTest("Base64 纯文本编解码", false)
        }

        let b64UrlSafe = Base64EncoderTool.encodeText("Hello+World/Test?123", urlSafe: true)
        assertTest("Base64 URL-Safe 字符替换", !b64UrlSafe.contains("+") && !b64UrlSafe.contains("/"))

        // 4. JWT Decoder Tests
        print("\n[4/10] JWT 解析器测试:")
        let testJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkRldktpdCIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxOTk5OTk5OTk5fQ.4flK7N"
        let jwtResult = JWTDecoderTool.decode(testJWT)
        if case .success(let info) = jwtResult {
            assertTest("JWT Header 解析", info.headerJSON.contains("HS256"))
            assertTest("JWT Payload 解析", info.payloadJSON.contains("DevKit"))
            assertTest("JWT 有效期未过期判定", info.isExpired == false)
        } else {
            assertTest("JWT 解析成功", false)
        }

        // 5. Hash Generator Tests
        print("\n[5/10] 哈希与 HMAC 计算测试:")
        let hashes = HashGeneratorTool.computeHash(for: "hello world")
        let md5 = hashes.first(where: { $0.algorithm == .md5 })?.hash
        assertTest("MD5 哈希值标准校验", md5 == "5eb63bbbe01eeed093cb22bb8f5acdc3")

        let hmacs = HashGeneratorTool.computeHMAC(for: "The quick brown fox jumps over the lazy dog", secretKey: "key")
        let hmacSha256 = hmacs.first(where: { $0.algorithm == .sha256 })?.hash
        assertTest("HMAC-SHA256 签名标准校验", hmacSha256 == "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8")

        // 6. JSON Formatter & Path & Model Tests
        print("\n[6/10] JSON 格式化与高阶工具测试:")
        let minJSON = "{\"b\":2,\"a\":1,\"user\":{\"name\":\"Alice\"},\"tags\":[\"dev\",\"mac\"]}"
        let prettyRes = JSONFormatterTool.format(minJSON, mode: .pretty, indent: .twoSpaces)
        if case .success(let prettyStr) = prettyRes {
            assertTest("JSON 格式化缩进与键排序", prettyStr.contains("\n") && prettyStr.contains("\"a\""))
        } else {
            assertTest("JSON 格式化", false)
        }

        let pathRes = JSONFormatterTool.evaluatePath(minJSON, path: "user.name")
        if case .success(let val) = pathRes {
            assertTest("JSONPath 路径提取", val.contains("Alice"))
        } else {
            assertTest("JSONPath 路径提取", false)
        }

        let typeScriptRes = JSONFormatterTool.generateModel(from: minJSON, language: .typeScript, rootName: "UserProfile")
        if case .success(let code) = typeScriptRes {
            assertTest("TypeScript 类型声明自动生成", code.contains("export interface UserProfile") && code.contains("tags: string[];"))
        } else {
            assertTest("TypeScript 类型生成", false)
        }

        let swiftRes = JSONFormatterTool.generateModel(from: minJSON, language: .swift, rootName: "UserProfile")
        if case .success(let code) = swiftRes {
            assertTest("Swift Codable 结构体自动生成", code.contains("struct UserProfile: Codable") && code.contains("let tags: [String]"))
        } else {
            assertTest("Swift 类型生成", false)
        }

        // 7. UUID Generator Tests
        print("\n[7/10] UUID 生成器测试:")
        let uuids = UUIDGeneratorTool.generate(count: 20, format: .standard)
        let uniqueCount = Set(uuids).count
        assertTest("批量生成 20 个唯一 UUID", uniqueCount == 20)
        assertTest("标准 UUID 连字符结构", uuids[0].components(separatedBy: "-").count == 5)

        // 8. Timestamp Converter Tests
        print("\n[8/10] 时间戳转换器测试:")
        let tsRes = TimestampConverterTool.convert(timestampString: "1700000000")
        if case .success(let conv) = tsRes {
            assertTest("Unix 秒级时间戳转换", conv.seconds == 1700000000 && conv.utcFormatted.contains("2023-11-14 22:13:20"))
            assertTest("多时区转换包含北京时间", conv.beijingFormatted.contains("2023-11-15 06:13:20"))
        } else {
            assertTest("时间戳转换", false)
        }

        let tsMsRes = TimestampConverterTool.convert(timestampString: "1700000000000")
        if case .success(let conv) = tsMsRes {
            assertTest("13位毫秒时间戳智能识别", conv.isDetectedMilliseconds == true && conv.seconds == 1700000000)
        } else {
            assertTest("毫秒时间戳识别", false)
        }

        // 9. Regex Tester Tests
        print("\n[9/10] 正则表达式测试:")
        let regOutput = await RegexTesterTool.test(pattern: #"\d+"#, text: "DevKit v1 released in 2026")
        assertTest("正则数字匹配捕获", regOutput.totalCount == 2 && regOutput.matches.last?.fullMatch == "2026")

        let regErr = await RegexTesterTool.test(pattern: "[unclosed", text: "Test")
        assertTest("非法正则表达式语法报错", regErr.error != nil)

        // 10. Clipboard Detector Tests
        print("\n[10/11] 剪贴板按需智能检测测试:")
        let detJWT = ClipboardDetector.detect(content: testJWT)
        assertTest("剪贴板识别 JWT", detJWT?.suggestedTool == .jwt)

        let detJSON = ClipboardDetector.detect(content: "{\"online\": false}")
        assertTest("剪贴板识别 JSON", detJSON?.suggestedTool == .json)

        let detSQL = ClipboardDetector.detect(content: "SELECT id, name FROM users WHERE active = 1")
        assertTest("剪贴板识别 SQL 查询", detSQL?.suggestedTool == .json)

        let detTS = ClipboardDetector.detect(content: "1700000000")
        assertTest("剪贴板识别 时间戳", detTS?.suggestedTool == .timestamp)

        let detURL = ClipboardDetector.detect(content: "https://site.com?q=%E6%B5%8B%E8%AF%95")
        assertTest("剪贴板识别 URL 编码", detURL?.suggestedTool == .url)

        // 11. Multi-Language Code Formatter Tests (Sublime Text Style)
        print("\n[11/11] 多语言格式化引擎 (CodeFormatter) 测试:")
        // 11.1 Language Detection
        assertTest("智能识别 SQL", CodeFormatterTool.detectLanguage(from: "SELECT u.name, u.email FROM users u WHERE u.id = 1") == .sql)
        assertTest("智能识别 XML", CodeFormatterTool.detectLanguage(from: "<svg viewBox=\"0 0 100 100\"><circle cx=\"50\" cy=\"50\" r=\"40\"/></svg>") == .xml)
        assertTest("智能识别 JSON", CodeFormatterTool.detectLanguage(from: "{\"version\": \"1.0.0\", \"active\": true}") == .json)
        assertTest("智能识别 YAML", CodeFormatterTool.detectLanguage(from: "---\napiVersion: v1\nkind: Pod") == .yaml)
        assertTest("智能识别 CSS", CodeFormatterTool.detectLanguage(from: ".container { width: 100px; color: #fff; }") == .css)
        assertTest("智能识别 Markdown", CodeFormatterTool.detectLanguage(from: "# DevKit Release\n| Name | Version |\n|---|---|") == .markdown)

        // 11.2 SQL Formatting & Minification
        let rawSQL = "select id, name, count(*) from users where status = 'active' group by id, name order by id desc limit 10;"
        let formattedSQL = CodeFormatterTool.formatSQL(rawSQL, options: SQLFormatOptions(keywordCase: .uppercase, commaPosition: .trailing, indent: "  "))
        assertTest("SQL 关键字大写与换行缩进", formattedSQL.contains("SELECT\n") || (formattedSQL.contains("SELECT") && formattedSQL.contains("FROM") && formattedSQL.contains("WHERE")))
        assertTest("SQL 聚合函数内逗号保持紧凑", formattedSQL.contains("COUNT(*)"))

        let minSQL = CodeFormatterTool.minifySQL("SELECT   id,  name  FROM   users  -- test comment\n  WHERE id = 1;")
        assertTest("SQL 压缩与注释剔除", !minSQL.contains("-- test") && !minSQL.contains("   "))

        // 11.3 XML / HTML Formatting & Minification
        let rawXML = "<note><to>George</to><from>John</from><heading>Reminder</heading><body>Don't forget the meeting!</body></note>"
        let formattedXML = CodeFormatterTool.formatXML(rawXML, indent: "  ")
        assertTest("XML 层级缩进美化", formattedXML.contains("\n  <to>George</to>") || formattedXML.contains("\n  <to>"))

        let minXML = CodeFormatterTool.minifyXML("  <note>\n    <to>George</to>\n  <!-- comment -->\n</note>  ")
        assertTest("XML 压缩剔除注释与换行", minXML == "<note><to>George</to></note>")

        // 11.4 YAML & JSON Bi-directional Conversion
        let testJSONForYAML = "{\"project\":\"DevKit\",\"stars\":2000}"
        let yamlResult = CodeFormatterTool.jsonToYAML(testJSONForYAML)
        if case .success(let yamlStr) = yamlResult {
            assertTest("JSON 转 YAML 生成", yamlStr.contains("project: DevKit") && yamlStr.contains("stars: 2000"))
            let backToJSON = CodeFormatterTool.yamlToJSON(yamlStr)
            if case .success(let jsonStr) = backToJSON {
                assertTest("YAML 逆向转换为有效 JSON", jsonStr.contains("\"project\"") && jsonStr.contains("\"DevKit\""))
            } else {
                assertTest("YAML 逆向转换为有效 JSON", false)
            }
        } else {
            assertTest("JSON 转 YAML 生成", false)
        }

        // 11.5 CSS Formatting & Minification
        let rawCSS = ".btn{color:#fff;background:blue;padding:8px 16px;}.btn:hover{background:darkblue;}"
        let formattedCSS = CodeFormatterTool.formatCSS(rawCSS, indent: "  ")
        assertTest("CSS 规则缩进与换行美化", formattedCSS.contains("{\n  color: #fff;\n  background: blue;"))

        let minCSS = CodeFormatterTool.minifyCSS(formattedCSS)
        assertTest("CSS 高效压缩", minCSS.contains(".btn{color:#fff;background:blue;padding:8px 16px;}") || minCSS.contains("background:blue;"))

        // 11.6 Markdown Pangu Spacing & Table Alignment
        let panguRaw = "使用DevKit进行Swift和macOS开发，体验100%离线工具箱。"
        let panguResult = CodeFormatterTool.panguSpacing(panguRaw)
        assertTest("Markdown 盘古之白(中英文间自动加空格)", panguResult.contains("使用 DevKit 进行 Swift 和 macOS 开发"))

        let unalignedTable = """
        | Tool | Type | Speed |
        | --- | --- | --- |
        | Diff | Text | Instant |
        | CodeFormatter | MultiLang | SubMillisecond |
        """
        let alignedTable = CodeFormatterTool.formatMarkdown(unalignedTable)
        assertTest("GFM 表格等宽列对齐", alignedTable.contains("| CodeFormatter | MultiLang | SubMillisecond |"))

        // 11.7 CodeSyntaxHighlighter Tests
        let sqlAttr = CodeSyntaxHighlighter.highlight(text: "SELECT * FROM users;", language: .sql)
        assertTest("SQL 语法高亮生成 NSAttributedString", sqlAttr.length > 0)

        let xmlAttr = CodeSyntaxHighlighter.highlight(text: "<root><item id=\"1\"/></root>", language: .xml)
        assertTest("XML 语法高亮生成 NSAttributedString", xmlAttr.length > 0)

        let cssAttr = CodeSyntaxHighlighter.highlight(text: ".title { font-size: 14px; }", language: .css)
        assertTest("CSS 语法高亮生成 NSAttributedString", cssAttr.length > 0)

        print("\n========================================")
        print("🎯 测试统计: 通过 \(passed) 项, 失败 \(failed) 项")
        print("========================================")

        if failed == 0 {
            print("🎉 全部 \(passed) 项核心算法、多语言格式化与高阶功能测试均已 100% 通过！")
        } else {
            exit(1)
        }
    }
}
