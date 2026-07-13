# PaperPulse Windows 迁移交接文档

更新日期：2026-07-12  
适用范围：以当前 `v0.1.1` 的 macOS/iOS 功能为基线，新增独立 Windows 客户端。  
本文件供新的 Codex 聊天任务直接阅读和执行。

## 结论先行

不要尝试将现有 macOS app 直接编译到 Windows，也不要把 Windows 做成对 SwiftUI、SwiftData、PDFKit 或 Apple Keychain 的“兼容层”。Swift 的 Windows 工具链、Swift Package Manager 与 SourceKit-LSP 已受官方支持，但这不等于 SwiftUI、SwiftData、PDFKit、AppKit 或 Security.framework 可以在 Windows 上运行。[Swift 平台支持](https://www.swift.org/platform-support/)

**推荐路线：使用 C# + WinUI 3 + Windows App SDK 创建原生 Windows 客户端，并将 `PaperCore` 的业务规则逐步移植为 C# 领域层。**

- 保持 `Apps/PaperPulseMac`、`Apps/PaperPulseiOS` 和现有 Swift `PaperCore` 原样可构建。
- Windows 端建立独立的工程与本地数据库；不直接读取 macOS 的 SwiftData store。
- 以 Swift `PaperCore` 的模型、JSON 编码和测试 fixtures 为行为规范，新增跨平台契约测试，避免检索、筛选、去重和 LLM 行为漂移。
- 第一版优先面向 Windows 11 x64；在测试与发布稳定后再增加 Windows on ARM64。

## 当前实施与验证模式

- Mac 是日常实现机，负责可移植 C# 模块、测试、文档、提交与推送。
- GitHub Actions 是 Windows 编译、核心测试、未签名 MSIX 打包与 artifact 的权威验证。
- Windows 11 只在同一 commit 的 CI 变绿后执行 F5、本地 MSIX 安装，以及 PasswordVault、WebView2、干净 VM 等运行时 gate。
- 不在两台设备间手工复制目录或归档；远端迁移分支是唯一交接源。

WinUI 3 是 Windows App SDK 提供的原生桌面 UI，支持 C#，并支持 MSIX、带外部位置的打包和未打包分发。[WinUI 入门](https://learn.microsoft.com/en-us/windows/apps/get-started/winui-get-started-overview)

## 当前工程盘点

### 可复用的行为规范

当前仓库的共享 Swift 包位于 `Sources/PaperCore`，包含：

- 学术来源：arXiv、OpenAlex、Crossref。
- 候选合并、去重、权威性筛选、关键词与排除词筛选、排序。
- 开放获取 PDF 下载、SHA-256、LLM provider 与简介/完整解读逻辑。
- JSON 模型与本地 profile 文件格式。
- 完整的 Swift 测试与 fixtures，尤其是 `Tests/PaperCoreTests/Fixtures/selected_manifest_sample.json`。

`PDFKitTextExtractor` 已通过 `#if canImport(PDFKit)` 降级，但 `PaperContentHash` 依赖 `CryptoKit`，其余共享层还使用 Foundation、FoundationXML 与 URLSession。即便 Swift CLI 在 Windows 上可运行，当前 macOS app 仍依赖 SwiftUI、SwiftData、PDFKit、Security 和 AppKit，不能直接迁移。

### 必须替换的 Apple 专属层

| 当前实现 | Windows 建议 | 迁移原则 |
| --- | --- | --- |
| SwiftUI / AppKit | WinUI 3 + XAML | 重做表现层，不复制 SwiftUI 代码。 |
| SwiftData | SQLite + `Microsoft.Data.Sqlite` | 显式 schema 与迁移脚本；不读取 `.store`。 |
| Security Keychain | `Windows.Security.Credentials.PasswordVault` | API Key 只进 Credential Locker，不进入 SQLite、日志或导出。 |
| PDFKit 阅读 | WebView2 本地 PDF 浏览 | 首版提供阅读、缩放和并排布局；不承诺 PDF 批注。 |
| PDFKit 文本抽取 | 独立 PDF 文本抽取适配器 | 先评估 `UglyToad.PdfPig` 等 NuGet 实现；以真实论文集做质量基准。 |
| macOS Application Support | `%LOCALAPPDATA%\\PaperPulse` | 数据、PDF、解读均落在 Windows 用户本地目录。 |
| Apple bundle / ad-hoc 签名 | MSIX + Windows 代码签名证书 | 发布前完成签名验证；不将未签名包作为正式公开版。 |

`Microsoft.Data.Sqlite` 是微软维护的轻量 ADO.NET SQLite provider，可直接使用或作为 EF Core SQLite provider 的底层。[Microsoft.Data.Sqlite 概览](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/)

Credential Locker 的 `PasswordVault` 适合保存小型凭据；官方特别说明不要将大数据块或明文凭据放入普通 app data。[Credential Locker](https://learn.microsoft.com/en-us/windows/apps/develop/security/credential-locker)

## 目标工程结构

在仓库根目录新增 `Apps/PaperPulseWindows/`，不要修改 Apple target 的构建配置。

```text
Apps/PaperPulseWindows/
  PaperPulse.Windows.sln
  src/
    PaperPulse.Contracts/       # DTO、枚举、JSON contract、共享 fixture 读取
    PaperPulse.Engine/          # 检索、合并、筛选、下载、排序、LLM provider
    PaperPulse.Storage/         # SQLite、文件路径、迁移、Credential Locker 适配器
    PaperPulse.Pdf/             # PDF 阅读与文本抽取抽象
    PaperPulse.Windows/         # WinUI 3 app、XAML、ViewModel、资源
  tests/
    PaperPulse.Contracts.Tests/
    PaperPulse.Engine.Tests/
    PaperPulse.Storage.Tests/
    PaperPulse.Windows.Tests/
  scripts/
    build.ps1
    test.ps1
    package.ps1
```

### 模块边界

1. `Contracts`：C# records 与 JSON converter。字段与 `Sources/PaperCore/Models.swift` 保持等价，先写 JSON fixture round-trip 测试。
2. `Engine`：使用 `HttpClient` 重写 `PaperDiscoveryService`、`PaperCandidateMerger`、`PaperRanker`、`PaperDownloader`、LLM providers。不得引用 WinUI 或 SQLite。
3. `Storage`：定义 repository interface，使用 SQLite 实现论文、订阅、订阅-论文关联、简介与完整解读元数据。文件由专用 file store 管理。
4. `Pdf`：定义 `IPdfReader` 与 `IPdfTextExtractor`。阅读器和抽取器可独立替换，避免第三方 PDF 组件泄漏到业务层。
5. `Windows`：只负责视图、命令、窗口状态和依赖注入，不在 code-behind 放检索或存储规则。

不要尝试从 C# 直接调用 Swift `PaperCore` 作为长期架构：Windows Swift 能编译命令行程序，但把它嵌入 WinUI/C# 会引入 ABI、部署和调试成本，且没有减少 Apple UI/存储层重写工作。Swift 工具链可作为短期行为对照工具，不应成为 Windows GUI 的运行时依赖。[Swift for Windows 安装](https://www.swift.org/install/windows/)

## 必须保留的产品契约

Windows 端需要与现有 macOS 行为一致：

- 每个订阅均由用户手动点击纸飞机推送论文；不在第一版恢复自动后台推送。
- 同一论文可属于多个订阅，但元数据、PDF 与完整解读各只保存一份。
- 论文库按订阅分组，未归类单独成组；各组可折叠。
- 选择订阅时自动展开该订阅，折叠其他订阅和未归类。
- 只有“收藏”，不引入“已读”分类。
- 机构、期刊/会议为空表示任意，但权威性筛选依然执行。
- 完整解读异步生成；未配置 API Key 时必须明确提示配置 API，不使用本地摘要冒充完整解读。
- 生成期间在简介区域显示清晰的进行中状态，用户仍可浏览其他论文。
- 完整解读与 PDF 默认 1:1 并排；分栏比例持久化。
- 删除完整解读必须确认，且只删除当前论文的解读文件。
- 界面语言与简介语言各自保存、互不绑定。

## Windows 本地数据设计

建议初始目录：

```text
%LOCALAPPDATA%\PaperPulse\
  PaperPulse.db
  PDFs\
  Interpretations\
  Logs\                  # 不记录 API Key、请求授权头或正文
```

SQLite 最小表：

- `feeds`：订阅配置 JSON 与创建时间。
- `papers`：以稳定 paper ID 唯一；包含 candidate JSON、摘要字段、PDF 相对路径与 SHA-256、收藏状态。
- `feed_papers`：`feed_id + paper_id` 唯一，表示多对多归属。
- `summaries`：短简介与完整解读元数据；完整解读 Markdown 文件保存相对路径。
- `settings`：界面语言、简介语言、最后选中订阅、PDF/解读分栏比例等非敏感偏好。
- `schema_migrations`：SQL 迁移版本和执行时间。

API Key 的迁移规则：

- Windows 端用 `PasswordVault`，resource 固定为 Windows bundle/app 标识，用户名使用 LLM profile UUID。
- macOS Keychain 不能也不应该导出到 Windows；首次导入数据后必须重新输入每个 API Key。
- 不实现 macOS 与 Windows 的自动同步。数据迁移应是显式的“导出 JSON + 复制 PDF/解读文件 + Windows 导入”工具，并在后续版本单独设计。

## PDF 与完整解读

### 阅读

WinUI 3 内嵌 `WebView2`，导航到 `file:///` PDF 路径。微软文档说明 WebView2 可加载本地 HTML 或 PDF；其 PDF 查看功能可用，但 PDF 注释、绘制与高亮在 WebView2 中不可用。[WebView2 本地内容](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/working-with-local-content)；[Edge 与 WebView2 的差异](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/browser-features)

实现要求：

- 左右 `GridSplitter` 默认 1:1，保存 `SplitRatio` 到 `settings`。
- 没有 PDF 时显示下载动作；下载中、解读生成中、失败和重试状态均可见。
- WebView2 仅用于查看；不要从 PDF viewer 的行为推断可抽取文本。

### 文本抽取

单独建立抽取 spike，不要在没有验证前承诺结果质量：

1. 选取中英文、双栏、扫描件、含公式的真实开放 PDF 各 10 篇。
2. 评估候选 NuGet 库的文本顺序、页码、内存、许可和异常处理。
3. 首选能返回页码锚点的实现；扫描 PDF 先标记“无可提取文本”，不在 V0.1 里引入 OCR。
4. 完整解读 prompt 保留来源页码与文本 hash；删除解读只删除该论文关联的 Markdown。

## 工具、工作负载与插件

### 必需安装

1. Windows 11 开发机；打开 Developer Mode。
2. 最新稳定版 Visual Studio，安装 **WinUI application development** 工作负载。微软目前的 WinUI 文档将它列为 C# + Windows App SDK 的必需工作负载。[环境配置](https://learn.microsoft.com/en-us/windows/apps/get-started/start-here?tabs=stable)
3. 与该 Visual Studio/Windows App SDK 匹配的 .NET SDK。创建 `global.json` 固定团队使用的 SDK major/minor。
4. Git for Windows。
5. Edge WebView2 Runtime。Windows 11 通常已有；安装器与测试机仍必须验证存在性。

### 项目 NuGet 包

| 包 | 用途 | 是否第一阶段必需 |
| --- | --- | --- |
| `Microsoft.WindowsAppSDK` | WinUI 3、窗口与 Windows API 基础 | 是 |
| `Microsoft.Web.WebView2` | 本地 PDF 阅读 | 是 |
| `Microsoft.Data.Sqlite` | SQLite 存储 | 是 |
| `CommunityToolkit.Mvvm` | 可测试的 MVVM 命令与 observable 状态 | 推荐 |
| `xunit`、`Microsoft.NET.Test.Sdk` | 单元测试 | 是 |
| PDF 文本抽取库 | 完整解读输入 | 在 spike 验证后加入 |

### IDE 插件 / 扩展

- **必需**：Visual Studio 的 `WinUI application development` 是工作负载，不是 Marketplace 插件。
- **条件必需**：若使用的 Visual Studio 版本没有内建 single-project MSIX 工具，安装微软的 **Single-project MSIX Packaging Tools** VSIX；较新 Visual Studio 中该功能已内建，先检查再安装。[single-project MSIX](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/single-project-msix)
- **可选**：VS Code 的官方 **Swift** 扩展，仅用于在 Windows 上编译/测试 Swift `PaperCore` 的可移植子集，不用于 WinUI C# 开发。[Swift VS Code 配置](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html)
- **不需要**：没有任何 Codex 插件是 Windows app 迁移的必需前置条件。GitHub 连接器、浏览器插件都只是辅助；当前任务中的内置浏览器已反复触发 `Bad Request`，新任务不要依赖它完成关键步骤。

## 推荐分阶段实施

### 阶段 0：冻结契约与建立 Windows 空壳

- 新建 `Apps/PaperPulseWindows`，不改 Apple target。
- 建立 packaged WinUI Blank App、x64 Debug/Release、基础 CI。
- 选择 Windows App SDK 的稳定版本并写入集中包版本管理。
- 写 `README` 或 Windows 开发说明，明确 Windows 数据不会读取 macOS 本地库。

验收：macOS `validate-core.sh`、Swift 基线测试和同一 commit 的 GitHub Windows workflow 通过；Windows 11 在 F5 与本地 MSIX 安装后生成 Phase0 gate 记录。CI artifact 保持未签名；由于 Windows 11 不接受直接安装该 artifact，本地验证可用仅存于本机证书库的自签名开发证书对副本签名，不能将其用于公开发布。

### 阶段 1：模型契约与检索核心

- 从 Swift 模型建立 C# 等价 records、枚举、JSON 编码。
- 复用/扩展 JSON fixtures，对比 Swift/C# 的输入输出。
- 迁移 HTTP client、arXiv parser、OpenAlex/Crossref adapter、候选合并与排序。

验收：相同 fixture 在两端产生同一稳定 paper ID、去重结果与排序顺序。

### 阶段 2：SQLite、文件系统与 API Key

- 实现数据库 schema 与 SQL migration。
- 实现 PDF/解读目录、原子下载、SHA-256、删除策略。
- 实现 `PasswordVault` 适配器和 profile metadata store。

验收：同论文多订阅只保留一份 PDF；重启后订阅、收藏、分组和非敏感设置仍存在；API Key 不在数据库或日志中。

### 阶段 3：订阅、资料库与筛选 UI

- 完成三栏/侧栏 Windows 布局、订阅编辑器、纸飞机手动推送。
- 完成按订阅折叠分组、未归类、搜索与收藏。
- 为所有必须保留的交互契约写 UI/集成测试。

验收：Windows UI 的关键行为与 macOS 契约一致，而不是像素级模仿。

### 阶段 4：PDF、完整解读与设置

- 接入 WebView2 本地 PDF、可持久化分栏。
- 接入验证后的 PDF 文本抽取器。
- 完成多 provider 设置、独立语言设置、API 测试、缺失 API Key 提示与生成中 UI。

验收：完整解读可异步生成、取消/失败可见、删除只影响当前论文。

### 阶段 5：发布与清洁环境验证

- GitHub Actions `windows-latest` 在每次推送执行 restore、build、portable tests、package。
- 用 MSIX 输出 x64 包；完成受信任代码签名后再公开发布。
- 评估 Microsoft Store 与 GitHub Releases + `.appinstaller`。MSIX 是推荐的单包发布路径；未打包 WinUI 3 不会生成单文件 EXE，且需要处理 Windows App SDK 运行时。[Windows 发布指南](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/publish-first-app)

验收：干净 Windows VM 安装、首次启动、PDF 下载、API 配置、生成解读、升级和卸载后的数据行为均有记录。

## 新聊天窗口的工作指令

将以下文本作为新 Codex 任务的第一条消息：

```text
请阅读 /Users/gabrielmu/Documents/papers/docs/development/windows-migration-handoff.md。

目标：在不影响现有 iOS、macOS 和 Swift PaperCore 构建的前提下，为 PaperPulse 启动 Windows 原生客户端迁移。先只实施“阶段 0”：创建 Apps/PaperPulseWindows 的 C# WinUI 3 工程空壳、基础目录、可重复的 build/test/package 脚本和 Windows 开发说明；不要迁移业务逻辑、不要修改 Apple app 的行为、不要发布或推送 GitHub。

开始前请检查当前 Git 分支与工作区；先列出将新增的文件、确认 Windows 工具链版本和所需工作负载。实施后运行 Windows 本地构建与测试（如当前机器没有 Windows 环境，应明确记录阻塞项并只完成不依赖 Windows 的结构与文档工作）。每完成一个阶段只创建本地 Git 提交，不推送，等待我确认下一阶段。

必须保留的产品契约以 windows-migration-handoff.md 为准。不要使用内置浏览器或 Computer Use；当前旧聊天任务会触发 {"detail":"Bad Request"}，关键操作请使用终端和明确的本地文件检查。
```

## 研究来源

- [Swift 平台支持与 Windows 工具可用性](https://www.swift.org/platform-support/)
- [Windows 安装 Swift 工具链](https://www.swift.org/install/windows/)
- [WinUI 3 与 Windows App SDK](https://learn.microsoft.com/en-us/windows/apps/get-started/winui-get-started-overview)
- [WinUI 开发环境与工作负载](https://learn.microsoft.com/en-us/windows/apps/get-started/start-here?tabs=stable)
- [Credential Locker / PasswordVault](https://learn.microsoft.com/en-us/windows/apps/develop/security/credential-locker)
- [Microsoft.Data.Sqlite](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/)
- [WebView2 本地文件与 PDF](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/working-with-local-content)
- [MSIX 单项目打包](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/single-project-msix)
- [Windows app 发布与未打包限制](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/publish-first-app)
