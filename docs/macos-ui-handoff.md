# PaperPulse macOS UI 重构交接文档

本文档用于在新的聊天窗口继续调整 PaperPulse 的 macOS 界面。它描述当前项目的边界、数据流、界面结构、可调整范围和验证方式。当前开发分支为 `codex/paperpulse-v1`；最近的本地提交为 `2097dcd`。

## 1. 产品目标与当前范围

PaperPulse 是一个本地优先的科研论文速递应用。用户创建若干订阅，手动向某个订阅推送近期论文；应用检索学术来源、规则排序、下载开放获取 PDF、生成短简介，并允许用户在单独的完整解读视图中阅读逐节分析。

macOS 和 iOS 使用共同的 `PaperCore`，但两端的数据库、Keychain、PDF 文件和订阅完全独立，当前没有同步功能。本轮 UI 工作只需关注 macOS；不要将 macOS 改成 iOS 的镜像界面。

当前 macOS 版本已具备：

- 多订阅创建、编辑、删除和手动“推送论文”。
- arXiv、OpenAlex、Crossref 的组合检索；仅保存确认可公开下载的 PDF。
- 按 DOI、arXiv ID 和标题哈希去重；同一篇论文可引用到多个订阅，但只保存一份 PDF 和一份论文实体。
- 基于关键词、分类、机构、期刊/会议、来源可信度、引用数和新近度的排序；可选 LLM 重排。
- LLM 配置文件、可自定义 Base URL、OpenAI-compatible / Anthropic / Gemini 格式、DeepSeek 等。
- 短简介、完整解读、PDF 并排阅读、收藏、搜索、分组折叠和未归类文章清理。
- 中英文界面切换和独立的简介输出语言选择。

当前没有要恢复的功能：定时推送、跨设备同步、付费墙绕过、Semantic Scholar 主流程、关系图或推荐网络。

## 2. 工程结构

```text
PaperPulse/
├── Sources/PaperCore/                 # 共享业务核心，不放 macOS 视觉逻辑
├── Tests/PaperCoreTests/               # 核心单元测试
├── Apps/PaperPulseMac/
│   ├── Sources/PaperPulseMac/          # macOS SwiftUI、SwiftData、Keychain
│   ├── Resources/                      # Info.plist、sandbox entitlement
│   └── Tests/PaperPulseMacTests/       # macOS 行为测试
├── Apps/PaperPulseiOS/                 # 独立 iOS App；本轮不改
├── project.yml                         # XcodeGen 的工程源文件
├── PaperPulse.xcodeproj/               # 由 XcodeGen 生成，通常不手工编辑
├── Package.swift                       # SwiftPM 的 PaperCore 定义
└── docs/                               # 开发、计划与本交接文档
```

关键原则：

- 修改 target、来源目录、entitlement 或 build setting 时先改 `project.yml`，之后执行 `scripts/generate_project.sh` 重新生成 Xcode 工程。
- 普通 SwiftUI/UI 修改只改 `Apps/PaperPulseMac/Sources/PaperPulseMac/`。
- 检索、下载、PDF 抽取、LLM 格式或排序规则属于 `Sources/PaperCore/`，不要为了视觉改动碰它们。
- `automation/` 是历史 Python/launchd 原型，仅供参考，不能作为 macOS App 的运行时依赖。

## 3. macOS App 的入口与依赖注入

入口文件：`Apps/PaperPulseMac/Sources/PaperPulseMac/PaperPulseMacApp.swift`。

`PaperPulseMacApp` 创建两个共享对象：

1. `PaperPulseMacModel`：界面状态、用户偏好、运行流程与命令入口。
2. `ModelContainer`：macOS 的 SwiftData 数据库容器。

两个 scene 都必须注入这两类依赖：

- `WindowGroup` 中的 `MacRootView`：`.environment(appModel).modelContainer(modelContainer)`。
- `Settings` 中的 `MacSettingsView`：同样注入 `.environment(appModel).modelContainer(modelContainer)`。

第二点很重要。早期设置页没有绑定同一容器，导致“清除未归类文章”在设置页中无法稳定更新主窗口。任何新增 Settings scene 或独立窗口都应沿用这套注入。

## 4. 当前界面层级

### 4.1 主窗口

主窗口根视图是 `MacRootView.swift`，使用 `NavigationSplitView`：

```text
MacRootView
├── sidebar: List
│   ├── 设置按钮
│   ├── 订阅区
│   │   ├── MacFeedRow：选中订阅、纸飞机推送按钮、右键菜单
│   │   └── 新建订阅
│   └── 论文库区
│       ├── 每个订阅一个 DisclosureGroup
│       └── 未归类一个 DisclosureGroup
└── detail: PaperDetailView / 空状态
```

侧边栏交互契约：

- 点击订阅行会选中该订阅，展开该订阅对应的论文组，折叠其余订阅和“未归类”。
- 每个分组可由用户手动折叠/展开。
- 纸飞机只向所在订阅推送；同一订阅已关联的论文跳过。不同订阅出现同一论文时仅添加引用，不重复存储 PDF。
- 论文库筛选仅保留“全部”和“收藏”，不再暴露“已读”。数据模型中仍有 `isRead`，是旧 SwiftData store 迁移兼容字段，不能直接删除。

主窗口目前最值得重新设计的部分就是侧边栏的层级、间距、类型排版、空状态、toolbar 位置和分组视觉，而不是其数据关系。

### 4.2 订阅编辑器

文件：`MacFeedEditorView.swift`。

编辑器是 sheet，固定约 `720 x 700`，内容可滚动，底部保存/取消按钮固定。它包含：

- 名称、arXiv 分类。
- 关键词库多选和自定义关键词；同一关键词列表内部为 OR。
- 排除关键词。
- 机构、期刊/会议文本输入。为空意味着“任意”，不额外约束，仍保留整体权威性评分。
- 学术来源复选框：arXiv、OpenAlex、Crossref。
- 每次推送数量和回溯天数。

筛选语义是：分类、关键词模块、机构模块、期刊/会议模块之间为 AND；机构或 venue 为空时对应模块不参与筛选。UI 文案不能把“任意”误写成“不做权威性判断”。

### 4.3 论文详情与完整解读

`PaperDetailView` 位于 `MacRootView.swift`，完整解读面板在 `MacFullInterpretationView.swift`。

- 常规详情左侧显示标题、作者、收藏、短简介、来源链接和“生成/打开完整解读”。
- 右侧是 `MacPDFView`，显示本地 PDF；未下载时显示空状态。
- 生成完整解读后，按钮改为“打开完整解读”。打开时左侧导航栏收起，解读 Markdown 与 PDF 以默认 1:1 并排显示。
- 用户拖动过分栏比例后通过 `@AppStorage("PaperPulse.macOS.detailSplitRatio")` 保存；不要在每次重新打开时重置用户比例。
- 解读面板有关闭和删除操作。删除需确认；关闭或删除后需要恢复侧边栏。
- 每篇论文各自持有完整解读 Markdown 文件，不能共用路径。

完整解读不是短简介的附加段落。它的结构来自 `PaperInterpretation`，包括研究问题与背景、结构概览、方法、数据与实验、主要结果、关键论证、局限、适合读者与延伸问题，并带 PDF 页码 anchors。

### 4.4 设置

文件：`MacSettingsView.swift`。

分组为：语言、关键词库、模型配置、存储。

- 界面语言与简介语言是不同设置。
- 模型配置允许多个 profile，名称默认来自模型名；profile 配置保存在 Application Support 的文件中，API Key 单独存 Keychain。
- Provider 支持 GPT、Claude、Gemini、DeepSeek、Qwen、GLM、Kimi 和 OpenAI-compatible 中转站；Base URL 是用户可编辑字段。
- “清除未归类文章”只删除当前没有任何有效订阅引用的论文、其简介及本地文件。收藏状态不影响是否被清除。

## 5. 数据模型与存储位置

SwiftData 实体定义在 `MacPersistenceStore.swift`：

| 实体 | 用途 | 要点 |
| --- | --- | --- |
| `MacFeedEntity` | 保存 `FeedConfig` JSON | 一个订阅一条记录 |
| `MacPaperEntity` | 论文元数据和本地 PDF 指针 | `id` 唯一，多个订阅共用 |
| `MacFeedPaperEntity` | 订阅与论文的多对多引用 | `feedID|paperID` 唯一 |
| `MacSummaryEntity` | 短简介或完整解读 | 完整解读有 Markdown 路径和页码锚点 |

主数据库：`~/Library/Application Support/PaperPulse-macOS.store`。

附属本地文件：

- PDF：`~/Library/Application Support/PaperPulse/macOS/PDFs/`
- 完整解读 Markdown：`~/Library/Application Support/PaperPulse/macOS/Interpretations/`
- LLM profile 配置：`~/Library/Application Support/PaperPulse/macOS/Model Configs/`
- API Key：macOS 登录 Keychain，service 为 `com.gabrielmu.PaperPulse.macOS`。

`MacPersistenceStore` 是唯一直接读写 SwiftData 的存储门面。UI 可以调用它查询，但复杂操作应优先收口进 `PaperPulseMacModel`，保证 Settings 和主窗口使用同一状态。例如 `clearUnclassifiedPapers()` 已经遵循该方式。

SwiftData 兼容约束：`MacPaperEntity.isRead` 已经不在 UI 使用，但必须保留并具有默认值，直到正式做版本化 schema 迁移。删除它会让已有用户数据库无法迁移。

## 6. 运行时数据流

### 6.1 手动推送一条订阅

```text
MacFeedRow 纸飞机
  -> PaperPulseMacModel.run(feed:)
  -> PaperPipeline.run(...)
     -> arXiv / OpenAlex / Crossref 检索
     -> 合并、规则排序、可选 LLM 重排
     -> 下载开放 PDF
     -> PDFKit 提取文本
     -> 生成短简介
  -> MacPersistenceStore 保存论文、简介、订阅引用
  -> @Query 驱动侧边栏论文库刷新
```

下载、PDF 提取或某一个来源失败时，管线保留其他成功结果。普通 UI 不应直接显示 `HTTPError error 0/3` 之类的内部错误码；应显示对应来源暂时不可用或可重试的文案。

### 6.2 生成完整解读

```text
详情页“生成完整解读”
  -> PaperPulseMacModel.generateFullSummary(for:)
  -> 本地 PDFKit 分页抽取
  -> LLM 分块解读，再汇总
  -> MacPersistenceStore.saveFullSummary(...)
  -> 每篇论文写入独立 Markdown
  -> 按钮切换为“打开完整解读”
```

完整解读为异步任务。界面必须允许用户在生成期间继续浏览、选择其他论文或执行其他操作；生成状态由 `fullSummaryPaperIDs` 按论文 ID 跟踪，错误由 `fullSummaryErrors` 按论文 ID 保存。

### 6.3 Keychain 授权框

启动时 `bootstrap` 会通过 `MacLLMProfileSettingsStore.loadProfiles` 读取每个 profile 的 API Key。因此 macOS 可能弹出 Keychain 授权框。开发阶段频繁构建的未签名 App 可能被系统视为新的可执行文件，即使此前点过“始终允许”仍可能再次要求授权。

这不是 DeepSeek API 失败。若重构设置页，应避免把 API Key 写入 UserDefaults 或数据库；保持 Keychain 存储。更理想的后续改进是延迟读取 Keychain，直到用户真的测试 API 或调用 LLM，以避免每次启动弹窗。

## 7. PaperCore：UI 重构时需要知道的公共能力

核心文件在 `Sources/PaperCore/`：

| 文件/类型 | 责任 |
| --- | --- |
| `Models.swift` | `FeedConfig`、论文、简介、权威策略等领域模型 |
| `PaperPipeline.swift` | 端到端的发现、处理、短简介流程 |
| `PaperDiscoveryService.swift` | 并发学术来源检索、合并和排序 |
| `PaperProcessingService.swift` | 下载、文本抽取和短简介处理 |
| `PaperSummaryService` | 完整解读的逐页 chunk + synthesis |
| `AcademicSources.swift` | arXiv、OpenAlex、Crossref 等适配器 |
| `PaperRanker.swift` | 确定性 authority/keyword/category/recency 排序 |
| `PaperDownloader.swift` | HTTPS、重定向、MIME、PDF 签名、大小限制和 hash 去重 |
| `LLMProviders.swift` | 官方 API 与中转站格式适配 |
| `PDFTextExtractor.swift` | PDFKit 提取与页码 anchors |

对于纯 UI 改造，默认不要修改这些文件。可以从 UI 层调用已有的 `PaperPulseMacModel` 方法；若 UI 需要新增显示数据，先确认 `FeedConfig`、`PaperRecord` 或 `PaperSummary` 已提供，再考虑扩展 model。

## 8. UI 重构时必须保持的行为契约

以下行为已经被用户明确要求，重构不得丢失：

1. 推送是每个订阅主动触发，不是定时任务。
2. 同一订阅不要重复推送已关联论文；不同订阅可以引用同一论文，共用本地存储。
3. 论文库按订阅分组，未归类单独一组；所有组可折叠。
4. 选择订阅会展开该订阅，折叠其他订阅和未归类。
5. 未归类指没有任何有效订阅引用的论文；设置中可删除未归类文章、摘要和本地文件。
6. 只保留收藏，不展示已读分类。
7. 机构与期刊/会议为空等于任意，不应把它解释为降低权威筛选。
8. 生成完整解读不能阻塞其他操作；完成后读解读与 PDF 并排、可以单独关闭或删除。
9. 删除完整解读需要确认，并且只删除当前论文对应的 Markdown/摘要记录。
10. 界面语言和简介语言分别管理；中文 UI 不能残留明显英文系统文案，除非是模型、来源或协议专名。

## 9. 当前视觉状态和建议切入点

当前 UI 使用原生 SwiftUI/AppKit 外观加少量 `Form`、`List`、`NavigationSplitView`、`DisclosureGroup`。其功能完整，但视觉层次和排版尚未统一。新聊天可以将这轮工作视为“只重塑表现层，保持数据和交互契约”。

推荐的 UI 重构顺序：

1. 定义 macOS 视觉 tokens：背景层、边框、主次文字、行高、圆角、侧边栏宽度、selection/focus 状态。优先用系统颜色和语义化样式，避免固定深色配色破坏系统浅色模式。
2. 重构 `MacRootView`：侧边栏信息架构、订阅行、论文库分组、空状态、搜索/筛选入口。
3. 重构 `PaperDetailView`：元数据头部、短简介阅读节奏、行动按钮、PDF 空状态和并排阅读转场。
4. 重构 `MacFeedEditorView`：改用清晰的分区、可读的筛选语义、合理的横向密度；保持 sheet 可滚动且 footer 固定。
5. 重构 `MacSettingsView`：将语言、模型、存储清理做成更明确的设置分区，避免模型配置字段看起来重复。
6. 最后补 macOS UI tests 或最少人工验收路径，不要先为了视觉效果改动持久化结构。

建议优先读取的文件：

- `Apps/PaperPulseMac/Sources/PaperPulseMac/MacRootView.swift`
- `Apps/PaperPulseMac/Sources/PaperPulseMac/MacLibraryView.swift`
- `Apps/PaperPulseMac/Sources/PaperPulseMac/MacFeedEditorView.swift`
- `Apps/PaperPulseMac/Sources/PaperPulseMac/MacSettingsView.swift`
- `Apps/PaperPulseMac/Sources/PaperPulseMac/MacFullInterpretationView.swift`

## 10. 已知问题与注意事项

- Keychain 授权可能在开发版反复出现，原因见第 6.3 节。
- 开发时 Release App 通常由 `CODE_SIGNING_ALLOWED=NO` 构建，适合本机测试，不是可分发产物。
- macOS 全面 UI 自动化尚未建立；现有 macOS 测试主要覆盖持久化、profile 存储和库筛选。
- 大型完整解读依赖外部 LLM，网络慢或模型响应慢时可能超时。当前 chunk 和 synthesis 已使用不同 timeout，但视觉上仍需要清晰的“生成中/失败后重试”状态。
- 详情页部分源链接和空状态仍可能使用英文固定文案，双语重构时应一并收口。
- 不要随意删除历史 PDF、Automation 文件或用户的 Application Support 数据库；它们可能是用户数据或测试 fixture。

## 11. 测试和构建

核心测试：

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/PaperPulseClangModuleCache \
  SWIFTPM_CONFIG_PATH=/private/tmp/PaperPulseSwiftPMConfig \
  SWIFTPM_CACHE_PATH=/private/tmp/PaperPulseSwiftPMCache \
  swift test
```

macOS 测试：

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/PaperPulseMacClangModuleCache \
  SWIFTPM_CONFIG_PATH=/private/tmp/PaperPulseMacSwiftPMConfig \
  SWIFTPM_CACHE_PATH=/private/tmp/PaperPulseMacSwiftPMCache \
  xcodebuild -project PaperPulse.xcodeproj -scheme PaperPulseMacTests \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/PaperPulseMacDerivedData \
  test CODE_SIGNING_ALLOWED=NO
```

macOS Release 构建：

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/PaperPulseMacClangModuleCache \
  SWIFTPM_CONFIG_PATH=/private/tmp/PaperPulseMacSwiftPMConfig \
  SWIFTPM_CACHE_PATH=/private/tmp/PaperPulseMacSwiftPMCache \
  xcodebuild -project PaperPulse.xcodeproj -scheme PaperPulseMac \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/PaperPulseMacReleaseDerivedData \
  build CODE_SIGNING_ALLOWED=NO
```

临时 Release App 输出位置：

```text
/private/tmp/PaperPulseMacReleaseDerivedData/Build/Products/Release/PaperPulse.app
```

UI 修改的最低人工验收路径：

1. 启动 App，检查浅色和深色模式下的侧边栏、分栏和文本对比度。
2. 选择一个订阅，确认对应论文组展开、其余组和未归类收起。
3. 手动推送一条订阅，确认 UI 显示运行状态、论文进入对应分组。
4. 打开论文，检查短简介、收藏、PDF 和完整解读按钮。
5. 生成或打开完整解读，检查 1:1 默认分栏、关闭/删除确认及侧栏恢复。
6. 在设置中切换双语、切换 LLM profile、清除未归类文章，确认主窗口立即更新。

## 12. 给下一轮聊天的建议提示

可以将下面这段直接作为新聊天的开场：

> 我在重构 PaperPulse 的 macOS UI。请先阅读 `docs/macos-ui-handoff.md`，只调整表现层，不改变其中第 8 节的交互与数据契约。先审阅 `MacRootView.swift`、`MacLibraryView.swift`、`MacFeedEditorView.swift`、`MacSettingsView.swift` 和 `MacFullInterpretationView.swift`，提出 2-3 套适合 macOS 论文阅读工具的视觉方向，等我选定后再实现。任何持久化、Keychain、PaperCore 或 iOS 改动都需要先说明理由。
