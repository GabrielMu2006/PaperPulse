# PaperPulse

PaperPulse 是一个面向科研论文发现、阅读与管理的 Apple 平台工具。它将订阅检索、权威性筛选、开放获取 PDF、本地资料库与用户自带 LLM 的论文解读整合在一起。

## 下载

### macOS V0.1.0

[下载 PaperPulse-v0.1.0-macOS-arm64.zip](https://github.com/GabrielMu2006/PaperPulse/releases/download/v0.1.0/PaperPulse-v0.1.0-macOS-arm64.zip)

- 支持 Apple silicon Mac，最低系统版本为 macOS 14。
- 解压后将 `PaperPulse.app` 放入“应用程序”目录即可使用。
- 当前 Release 未使用 Developer ID 签名或 Apple 公证。首次运行若被系统拦截，请在“系统设置 -> 隐私与安全性”中选择“仍要打开”。
- 论文库、PDF 与完整解读保存在本机；更新 App 不会自动清除这些资料。API Key 保存在 Keychain。

## macOS V0.1.0 已包含

- 按订阅手动点击纸飞机检索并推送论文。
- 同一篇论文可归入多个订阅，本地论文与 PDF 只保存一份。
- 按订阅和“未归类”分组的本地资料库，支持折叠、搜索与收藏。
- 面向 arXiv、OpenAlex、Crossref 等学术来源的权威性筛选与开放获取 PDF 下载。
- 用户可配置 OpenAI-compatible、Anthropic、Gemini 及自定义 LLM 服务。
- 中文/英文界面与论文简介语言可独立设置。
- PDF 与完整解读的桌面并排阅读，支持异步生成、删除确认和比例记忆。

## 项目结构

```text
Apps/                 iOS 与 macOS SwiftUI 应用
Sources/PaperCore/    共享检索、下载、排序与 LLM 核心
Tests/                PaperCore 测试
docs/                 开发、macOS 与发布文档
scripts/              XcodeGen 与 macOS 打包脚本
project.yml           XcodeGen 工程定义
```

## 本地开发

需要 Xcode 与本仓库提供的 XcodeGen 工具。重新生成工程：

```bash
./scripts/generate_project.sh
```

创建 macOS Release 归档：

```bash
./scripts/package_macos_release.sh 0.1.0
```

详情见 [开发环境说明](docs/development/setup.md) 与 [macOS 发布说明](docs/development/macos-release.md)。

## 安全与数据

- 仅下载可公开访问的 PDF，不绕过登录、订阅或付费墙。
- API Key 保存在系统 Keychain，不写入 Git、日志或应用偏好设置。
- macOS 与 iOS 的本地资料库和 API 配置彼此独立，不会自动同步。
