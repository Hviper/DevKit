# DevKit 🛠️

> **超轻量、纯原生、极致丝滑的 macOS 开发者瑞士军刀**
> 
> 基于 **Swift + SwiftUI + AppKit** 打造，**零第三方外部依赖**，打包产物体积仅 **~4.2MB**，毫秒级冷启动，支持 Menu Bar 菜单栏常驻与独立主窗口。

[![Latest Release](https://img.shields.io/github/v/release/Hviper/DevKit?label=Latest%20Release&color=blue)](https://github.com/Hviper/DevKit/releases/latest)
[![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-brightgreen)](https://github.com/Hviper/DevKit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

### 🚀 立即下载

| 下载渠道 | 文件类型 | 适用架构 | 下载链接 |
| :--- | :--- | :--- | :--- |
| **DMG 镜像安装包** | `.dmg` (~3.0MB) | Apple Silicon (M1/M2/M3/M4) | [**下载 DevKit-v1.0.1-macOS-arm64.dmg**](https://github.com/Hviper/DevKit/releases/download/v1.0.1/DevKit-v1.0.1-macOS-arm64.dmg) |
| **便携压缩包** | `.zip` (~2.5MB) | Apple Silicon (M1/M2/M3/M4) | [**下载 DevKit-v1.0.1-macOS-arm64.zip**](https://github.com/Hviper/DevKit/releases/download/v1.0.1/DevKit-v1.0.1-macOS-arm64.zip) |

---

## ✨ 核心特性

- ⚡️ **极致轻量**：纯 Swift 原生打造，不依赖 Electron 或 Webview，内存占用低至几十兆，体积仅 ~4.2MB。
- 🔍 **全局 ⌘F 搜索与替换**：全模块覆盖，支持实时匹配指示器、前后跳转、大小写敏感、GPU加速高亮与单处/全部替换。
- 💡 **双击相同词高亮**：类似 Sublime Text / VS Code 体验，双击任意单词即刻高亮全文出现位置，辅助代码与日志阅读。
- 📋 **按需智能剪贴板识别**：展开工具箱或点击呼出时按需解析剪贴板（绝不在后台常驻轮询吃电吃 CPU），智能推荐跳转对应工具。
- 📌 **窗口置顶与快捷切换**：支持 `⌘P` 窗口置顶（失焦不收起）、`⌘K` 快速定位工具、`⌘1 ~ ⌘9` 数字键一键直达各工具。

---

## 🧰 功能矩阵

| 模块 | 核心能力 |
| :--- | :--- |
| **文本比对 (Diff)** | 基于 Myers 算法的高性能差异对比，支持忽略空白字符与大小写、内联字词级差异标记、一键快速跳转至首处 Diff |
| **代码格式化 (Format)** | 支持 **SQL、JSON、XML、YAML、CSS、Markdown** 6 大语言，智能语法识别、美化/压缩、YAML 与 JSON 双向转换、Markdown 盘古之白与 GFM 表格对齐 |
| **JSON 工具箱** | JSON 美化缩进与紧凑压缩、JSONPath 实时语法提取、一键自动生成 **Swift Codable** 结构体与 **TypeScript Interface** 类型声明 |
| **JWT 解析器** | 自动解码 JWT 头部 (Header) 与载荷 (Payload)，实时校验有效时间戳与过期状态展示 |
| **Base64 编解码** | 文本 Base64 快速编解码、URL-Safe 模式转换、本地图片一键编码与 Data URL 图片实时渲染预览 |
| **URL 编解码** | URL 参数编码与解码还原、自动解析并结构化提取 Query 参数键值对表格，支持单个与批量复制 |
| **正则表达式 (Regex)** | 正则表达式实时验证与匹配高亮、捕获组多色提取、内置邮箱/IP/手机号/链接等常用模板 |
| **哈希与签名 (Hash)** | 支持 MD5、SHA1、SHA256、SHA512 等多算法并发计算，支持 HMAC 密钥签名验证与大小写输出切换 |
| **时间戳转换** | 实时系统时钟、10位秒级与 13位毫秒级时间戳双向转换、图形化日期时间选择器、支持多时区对应换算 |
| **UUID 生成器** | 批量生成 1~100 个唯一 UUIDv4，支持标准连字符、紧凑型、大写与小写格式 |

---

## ⌨️ 快捷键指南

| 快捷键 | 功能描述 |
| :--- | :--- |
| `⌘1` ~ `⌘9` | 切换左侧功能工具箱（Diff、URL、Base64、Hash、Format、UUID、时间戳、Regex、JWT） |
| `⌘F` | 在所有文本类工具中唤出搜索/替换浮动栏 |
| `Enter` / `Shift+Enter` | 搜索条中跳转至 下一个 / 上一个 匹配项 |
| `Esc` | 关闭当前搜索栏 |
| `⌘K` | 快速聚焦左侧工具过滤搜索框 |
| `⌘P` | 切换窗口是否置顶（钉住窗口） |
| `⌘W` / `⌘Q` | 关闭窗口 / 退出程序 |

---

## 🏗️ 架构与构建

### 系统要求
- macOS 13.0 (Ventura) 及以上
- Xcode 15.0+ / Swift 5.9+

### 快速构建与运行

```bash
# 克隆代码
git clone https://github.com/Hviper/DevKit.git
cd DevKit

# 运行核心单元测试 (50项核心算法覆盖)
swift run DevKitTestRunner

# 编译 Release 高性能版本
swift build -c release --product DevKit

# 打包成原生 macOS App Bundle 并启动
mkdir -p build/DevKit.app/Contents/MacOS
cp .build/release/DevKit build/DevKit.app/Contents/MacOS/DevKit
open build/DevKit.app
```

---

## 📄 License

[MIT License](LICENSE)
