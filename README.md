# PaperPulse

PaperPulse 是一款面向科研论文发现、阅读与管理的 Apple 平台工具。它把“订阅一个研究方向”延伸为一条本地优先的工作流：从学术来源检索、规则筛选与开放获取 PDF 下载，到短简介、完整解读和可长期维护的本地资料库。

它的原则很简单：**先可靠，再智能**。检索、合并、去重和开放获取判断优先使用可验证的学术来源和确定性规则；LLM 用于辅助理解论文，而不替代来源判断。

## 下载与系统要求

### macOS V0.1.0

[下载 PaperPulse-v0.1.0-macOS-arm64.zip](https://github.com/GabrielMu2006/PaperPulse/releases/download/v0.1.0/PaperPulse-v0.1.0-macOS-arm64.zip)

- 仅支持 Apple silicon Mac，最低系统版本为 macOS 14。
- 下载 ZIP 后解压，将 `PaperPulse.app` 拖入“应用程序”。
- 当前 Release 尚未经过 Apple Developer ID 签名和公证。首次运行若被系统拦截，请在 Finder 中对 app 右键选择“打开”，或在“系统设置 -> 隐私与安全性”中选择“仍要打开”。
- macOS 和 iOS 各自保存独立的本地数据与模型配置，当前不会自动同步。

> 从 GitHub 更新版本不会自动清除论文库、PDF 或完整解读。手动删除 app 也不会自动删除这些本地资料。

## 5 分钟上手

### 1. 配置界面与简介语言

打开左侧边栏的“设置”：

- **界面语言**：控制菜单、按钮和应用内提示的中文/英文显示。
- **简介语言**：控制 LLM 生成的短简介与完整解读的输出语言。
- 两者互不绑定，例如可以使用英文界面，同时生成中文论文解读。

### 2. 配置 LLM API

论文检索、规则筛选和开放获取 PDF 下载不依赖 LLM；但生成论文短简介和完整解读需要配置可用的模型服务。

在“设置 -> 模型配置”中完成以下步骤：

1. 在“新建配置”中选择服务商预设，或选择“自定义”。
2. 确认 **API 格式**、**Base URL**、**模型** 是否与服务商文档一致。
3. 在 **API Key** 中输入密钥，点击“保存配置”。
4. 点击“测试 API”。测试会发送一次很小的简介请求，用于验证 Key、模型名、接口地址与返回格式；这通常会产生少量模型费用。

PaperPulse 会预填下列官方服务的常用接口信息。模型名会随服务商更新而变化，请以服务商控制台和文档为准。

| 服务商 | API 格式 | 默认 Base URL |
| --- | --- | --- |
| OpenAI / GPT | OpenAI-compatible | `https://api.openai.com/v1` |
| Anthropic / Claude | Anthropic Messages | `https://api.anthropic.com/v1` |
| Google / Gemini | Gemini GenerateContent | `https://generativelanguage.googleapis.com/v1beta` |
| 阿里云百炼 / Qwen | OpenAI-compatible | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| 智谱 / GLM | OpenAI-compatible | `https://open.bigmodel.cn/api/paas/v4` |
| Moonshot / Kimi | OpenAI-compatible | `https://api.moonshot.cn/v1` |
| DeepSeek | OpenAI-compatible | `https://api.deepseek.com` |

### OpenAI-compatible 中转或自建服务

若服务商提供 OpenAI Chat Completions 兼容接口：

1. 新建“自定义”配置，或选择对应服务商后修改预设。
2. 将 **API 格式** 设为 `OpenAI-compatible`。
3. 填入服务商提供的 Base URL，例如 `https://example.com/v1`。不要填写完整的 `/chat/completions` 地址，应用会自动补上该路径。
4. 填入服务商文档规定的模型标识和 API Key，再点击“测试 API”。

若服务商使用 Anthropic Messages 或 Gemini GenerateContent 原生协议，请选择相应 API 格式，并填入该协议对应的 Base URL。API 格式与服务端不匹配时，常见结果是 `404`、`401`、模型不存在或返回格式错误。

### API Key 保存位置

- API Key 只保存在当前 Mac 的系统 **Keychain**，不会写入 Git、日志或普通偏好设置。
- 配置名称、服务商、Base URL 和模型名保存在本地配置文件中，但不包含 API Key。
- 删除一个模型配置只会删除该配置对应的 Keychain 密钥；不会影响其他模型配置。

## 创建论文订阅

在左侧边栏点击“新建订阅”，设置以下内容：

- **名称**：例如“具身智能”“多模态推理”或“Agent”。
- **分类**：用于 arXiv 的分类，如 `cs.AI, cs.CL`，以逗号分隔。
- **关键词**：任一关键词匹配即可纳入候选；可从关键词库选择，也可填写自定义关键词。
- **排除关键词**：以逗号分隔，用于排除不相关方向。
- **机构、期刊或会议**：留空表示“任意”，不会取消权威性判断；填写后作为额外筛选条件。
- **学术来源**：可组合启用 arXiv、OpenAlex、Crossref。
- **每次篇数**：单次推送保留的论文数量，范围为 1 至 20。
- **检索范围**：向前检索的天数，范围为 1 至 30。

保存订阅后，点击该订阅右侧的纸飞机按钮即可手动推送论文。当前版本不会在后台自动推送，所有检索都由用户明确触发。

## 推送后会发生什么

一次推送会按以下顺序执行：

1. 从启用的学术来源获取候选论文。
2. 使用标题、DOI、arXiv ID 等信息合并与去重。
3. 按关键词、排除词、时间范围、机构/期刊会议要求和权威性规则筛选。
4. 只下载确认可公开访问的 PDF；不会绕过付费墙、登录或机构订阅。
5. 保存论文元数据、PDF 和短简介到本地资料库。

同一论文可以属于多个订阅，但论文数据与 PDF 在本机只保存一份。若某个订阅已经关联过这篇论文，后续向该订阅推送时会跳过重复内容。

## 阅读与资料库

- 论文库按订阅分组，并单独显示“未归类”分组；各组可折叠。
- 选中某个订阅会自动展开它的论文组，并折叠其他订阅和未归类分组，便于专注当前方向。
- 支持本地搜索与收藏。当前版本只保留“收藏”，不提供“已读”分类。
- 可在论文详情中生成完整解读。生成任务异步执行，完成后可与 PDF 默认 1:1 并排阅读。
- 调整过的 PDF/解读分栏比例会被记住。删除完整解读时会要求确认，且只删除当前论文的解读文件。

## 数据与隐私

- 论文库、PDF 与完整解读保存在本机。
- macOS 数据库位于 `~/Library/Application Support/PaperPulse-macOS.store`。
- PDF 位于 `~/Library/Application Support/PaperPulse/macOS/PDFs/`；完整解读位于 `~/Library/Application Support/PaperPulse/macOS/Interpretations/`。
- “清除未归类文章”会删除当前没有任何订阅引用的论文、对应简介与本地文件，请谨慎使用。
- PaperPulse 仅处理公开可访问的 PDF，不尝试绕过付费墙、订阅或认证机制。

## 当前能力与后续规划

macOS V0.1.0 已提供订阅检索、开放获取 PDF、本地资料库、收藏、短简介、完整解读和多服务商模型配置。iOS 与 macOS 共享检索、下载、排序和 LLM 核心，但两端目前独立运行与存储。

后续将持续完善：

- iOS 的独立阅读与资料库体验。
- 更多学术来源与开放获取验证能力，例如 Semantic Scholar、Unpaywall。
- 多来源合并、机构/期刊会议筛选与排序的可解释性。
- 长论文解析、页码锚点和完整解读质量。
- 可选的后台刷新与调度能力，同时保持用户对触发频率和数据流的控制。
- macOS 的 Developer ID 签名与 Apple 公证分发。

## 开发

项目使用 SwiftUI、SwiftData、PDFKit、Swift Package Manager 与 XcodeGen。重新生成 Xcode 工程：

```bash
./scripts/generate_project.sh
```

构建本地 macOS Release：

```bash
./scripts/package_macos_release.sh 0.1.0
```

更多开发信息见 [开发环境说明](docs/development/setup.md) 与 [macOS 发布说明](docs/development/macos-release.md)。
