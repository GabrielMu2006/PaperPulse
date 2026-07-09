# PaperPulse

PaperPulse 是一个面向科研阅读的 Apple 平台 App，目标是在 iPhone 和 Mac 上独立完成“定时检索最新论文 -> 权威性筛选 -> 下载开放 PDF -> 生成简介 -> 离线阅读与管理”的完整流程。

> 当前 GitHub 仓库先只放项目说明 README；本地源码暂不推送。

## 成品目标

- 支持用户配置研究领域、关键词、排除词、每日篇数，以及机构/期刊/会议偏好。
- 以确定性学术 API 为主获取论文信息，优先覆盖 arXiv、OpenAlex、Crossref、Unpaywall 等来源。
- 只下载开放获取 PDF，不绕过登录、订阅或付费墙。
- iOS 版可以独立运行：手动刷新、最佳努力后台刷新、后台下载、离线阅读、本地通知、完整简介生成。
- macOS 版提供桌面调试与阅读管理能力，但 iOS 不是 macOS 的同步客户端。
- 支持用户自带 LLM API Key，支持 OpenAI-compatible、自定义 Base URL/中转站、模型名和能力开关。
- 支持中文/英文界面切换，以及中文/英文论文简介输出。

## 已实现内容

- 建立 SwiftPM 项目 `PaperPulse`，核心库目标为 `PaperCore`，最低系统版本为 iOS 17 / macOS 14。
- `PaperCore` 已包含核心模型、协议、pipeline、持久化 payload、排序器、下载器、PDF 文本抽取器和本地规则摘要 fallback。
- 已实现 arXiv Atom 解析与学术源适配基础，并包含 OpenAlex、Crossref、Unpaywall 等来源的核心客户端/补全逻辑。
- 已实现 DOI、arXiv ID、标题 hash 等去重与规则排序框架。
- 已实现 App 自有 `URLSession` PDF 下载校验，包括 MIME、大小、PDF 签名、安全文件名和重复文件处理。
- 已实现 LLM provider 抽象：OpenAI-compatible Chat Completions、Anthropic Messages、Gemini GenerateContent。
- Provider 配置已覆盖 GPT/OpenAI、Claude、Gemini、Qwen、GLM、Kimi、DeepSeek 和自定义 Base URL；DeepSeek 可作为 OpenAI-compatible 总结模型接入。
- iOS App 已有 SwiftUI 页面结构：Feeds、Today、Library、Settings，并包含 SwiftData 实体、Keychain API Key 保存、后台刷新协调器、摘要语言和界面语言设置。
- macOS App 已有 SwiftUI 基础结构、Settings、Keychain 和 provider 配置存储。
- 已添加 `PaperCoreTests`，覆盖解析、下载、排序、provider、pipeline、持久化 payload 等核心行为。

## TODO List

- 完成真实 API 集成验收：arXiv、OpenAlex、Crossref、Unpaywall、DeepSeek 及其他 OpenAI-compatible 中转站。
- 在 App 内完善 LLM 二次重排：规则筛选先出候选集，LLM 只在候选集内解释推荐理由和微调排序，不允许编造机构或引用。
- 完善权威性策略 UI：机构白名单/黑名单、期刊/会议偏好、引用数阈值、来源可信度权重。
- 增强完整论文简介：章节分块、page anchors、方法/贡献/实验/局限/适合谁读等结构化输出。
- 完善 Library 搜索、筛选、收藏、已读状态、PDF 导出和 iCloud/Files 管理。
- 完成 iOS BackgroundTasks 与 background URLSession 的恢复测试；明确“最佳努力后台刷新”和“精确定时需云端调度”的边界。
- 增加真实设备/模拟器验收：创建订阅、检索论文、下载 PDF、离线打开、生成短简介和完整简介、收到本地通知。
- 补充 App 图标、隐私说明、权限说明、发布配置和 App Store 所需材料。
- 后续再决定是否启用可选云端调度器与 APNs，用于精确定时和跨设备同步。
