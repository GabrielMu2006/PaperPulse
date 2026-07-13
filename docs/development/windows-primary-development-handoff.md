# PaperPulse Mac-First Windows 运行时交接文档

更新日期：2026-07-13

本文定义当前工作方式：Mac 负责日常 Windows 迁移代码与提交；GitHub Actions 负责 Windows 编译、测试与 MSIX 打包；Windows 11 仅负责 CI 无法证明的运行时验证。

## 一句话结论

后续 Windows 迁移不在两台设备间轮流开发：

- Mac 编写 portable Contracts、Engine、Storage、PDF abstractions、测试与文档，并推送迁移分支。
- GitHub Actions 对每次推送执行 Windows build、portable tests、unsigned MSIX package 和 artifact upload。
- Windows 11 只在同一 commit CI 变绿后执行 F5、本地 MSIX 安装与命名 runtime gate。
- 所有状态通过 Git 与 validation record 保存；不要依赖聊天或手工文件传递。

本文件后续保留的“Windows 主开发机”描述是旧工作方式的历史背景；如与上述规则冲突，以上述规则为准。

## 当前仓库状态

当前 Mac 仓库路径：

```text
/Users/gabrielmu/Documents/papers
```

远端：

```text
origin https://github.com/GabrielMu2006/PaperPulse.git
```

当前分支：

```text
codex/paperpulse-windows-migration
```

迁移分支当前保留以下基础提交：

```text
97c025a docs: add windows primary development handoff
83bc79d docs: add windows migration transfer guide
ab63f04 chore: scaffold PaperPulse Windows phase 0
a241f27 docs: add windows migration handoff
```

这 3 个提交都应保留：

- `a241f27`：Windows 迁移总 handoff，定义技术路线、产品契约、阶段边界和资料来源。
- `ab63f04`：Phase 0 Windows 工程空壳，创建 `Apps/PaperPulseWindows`。
- `83bc79d`：跨设备转移说明，记录如何把当前工作交给 Windows 机器。
- `97c025a`：Windows 主开发机交接说明，定义 Windows 作为长期开发环境的工作方式。

本文是 Windows 主开发工作流的补充文档。

## 已完成内容

已经创建：

```text
Apps/PaperPulseWindows/
  PaperPulse.Windows.sln
  global.json
  Directory.Build.props
  Directory.Packages.props
  README.md
  scripts/
    build.ps1
    test.ps1
    package.ps1
  src/
    PaperPulse.Contracts/
    PaperPulse.Engine/
    PaperPulse.Storage/
    PaperPulse.Pdf/
    PaperPulse.Windows/
  tests/
    PaperPulse.Contracts.Tests/
    PaperPulse.Engine.Tests/
    PaperPulse.Storage.Tests/
    PaperPulse.Windows.Tests/
```

Phase 0 只包含 WinUI 3 空壳、项目结构、脚本和边界测试。它没有迁移任何业务逻辑。

当前 Mac 上已验证：

```text
swift test
xcodebuild -project PaperPulse.xcodeproj -scheme PaperPulseMacTests -configuration Debug -derivedDataPath /private/tmp/PaperPulseMacDerivedData test CODE_SIGNING_ALLOWED=NO
```

两者均已通过，说明 Windows 子树没有破坏现有 Swift package 和 macOS app。

当前 Mac 上不能验证：

- `dotnet build`
- WinUI 3 F5 运行
- Windows App SDK 运行时行为
- WebView2 PDF 查看
- MSIX 打包安装
- Credential Locker / PasswordVault
- Windows 本地文件路径和 `%LOCALAPPDATA%\PaperPulse`

这些全部交给 Windows 主开发机完成。

## 第一次转移到 Windows

在 Mac 上把当前分支推到 GitHub：

```bash
cd /Users/gabrielmu/Documents/papers
git status --short --branch
git push origin codex/paperpulse-windows-migration
```

在 Windows 上克隆：

```powershell
git clone https://github.com/GabrielMu2006/PaperPulse.git
cd PaperPulse
git checkout codex/paperpulse-windows-migration
```

如果 Windows 上已有仓库：

```powershell
cd PaperPulse
git fetch origin
git checkout codex/paperpulse-windows-migration
git pull --ff-only
```

确认最近提交：

```powershell
git log --oneline --decorate --max-count 5
git status --short --branch
```

期望看到：

```text
97c025a docs: add windows primary development handoff
83bc79d docs: add windows migration transfer guide
ab63f04 chore: scaffold PaperPulse Windows phase 0
a241f27 docs: add windows migration handoff
```

## Windows 主开发机工具链

Windows 电脑需要：

- Windows 11 x64。
- Developer Mode 已开启。
- Visual Studio 2026 或当前稳定 Visual Studio。
- Visual Studio `WinUI application development` workload。
- 与 `Apps/PaperPulseWindows/global.json` 匹配的 .NET SDK。
- Git for Windows。
- Edge WebView2 Runtime。
- PowerShell 7，或系统自带 Windows PowerShell。

当前 Windows 工程约束：

```text
TargetFramework: net10.0-windows10.0.19041.0
TargetPlatformMinVersion: 10.0.17763.0
RuntimeIdentifiers: win-x64
Package type: MSIX
```

当前关键 NuGet 版本在：

```text
Apps/PaperPulseWindows/Directory.Packages.props
```

当前版本：

```text
Microsoft.WindowsAppSDK 2.2.0
Microsoft.Web.WebView2 1.0.4078.44
Microsoft.Data.Sqlite 10.0.9
CommunityToolkit.Mvvm 8.4.2
xunit 2.9.3
Microsoft.NET.Test.Sdk 18.7.0
```

如果 Windows 上 restore 失败，优先检查：

- .NET SDK 是否匹配 `global.json`。
- Visual Studio 是否安装 WinUI workload。
- NuGet 源是否可访问。
- Windows App SDK 当前版本是否与已安装 Visual Studio 支持范围匹配。

不要为了让 restore 通过而随意降级目标框架或移除 WinUI/MSIX 配置；应先记录错误，再做最小修复。

## Windows 上的 Codex 工作方式

在 Windows 上打开 Codex 时，工作目录应设为仓库根目录，例如：

```text
C:\Users\gabriel\src\PaperPulse
```

不要只打开：

```text
Apps\PaperPulseWindows
```

原因：Windows 迁移需要同时读取：

```text
docs/development/windows-migration-handoff.md
docs/development/windows-migration-transfer.md
docs/development/windows-primary-development-handoff.md
Apps/PaperPulseWindows/README.md
Sources/PaperCore
Tests/PaperCoreTests
```

Codex 新任务的第一条 prompt 建议使用：

```text
请在 Windows 主开发机继续 PaperPulse Windows 原生迁移。

先阅读：
- docs/development/windows-migration-handoff.md
- docs/development/windows-migration-transfer.md
- docs/development/windows-primary-development-handoff.md
- Apps/PaperPulseWindows/README.md

当前只处理我明确指定的阶段；如果我没有指定阶段，默认只做 Phase 0 Windows 验证。

工作规则：
1. 先检查 git status、当前分支、最近提交。
2. 先确认 Windows 工具链：dotnet --info、PowerShell、Visual Studio 版本、WinUI application development workload、Developer Mode、WebView2 Runtime。
3. 关键操作使用终端、本地文件和 Visual Studio/.NET 工具链；不要依赖内置浏览器或 Computer Use 完成核心步骤。
4. 不要修改 Apps/PaperPulseMac、Apps/PaperPulseiOS、Sources/PaperCore 或 PaperPulse.xcodeproj 的行为，除非我明确要求跨平台契约更新。
5. 不要推送 GitHub，不要创建 PR，不要发布安装包，除非我明确要求。
6. 每完成一个阶段，只创建本地 Git 提交，等待我确认下一阶段。
7. 如果遇到 Windows 工具链阻塞，请记录具体命令、错误、环境版本和最小修复建议。
```

## Phase 0 在 Windows 上的验收

进入 Windows 仓库后运行：

```powershell
cd Apps\PaperPulseWindows
dotnet --info
.\scripts\build.ps1 -Configuration Debug
.\scripts\test.ps1 -Configuration Debug
.\scripts\package.ps1
```

如果 PowerShell 执行策略阻止脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Configuration Debug
powershell -ExecutionPolicy Bypass -File .\scripts\test.ps1 -Configuration Debug
powershell -ExecutionPolicy Bypass -File .\scripts\package.ps1
```

还需要在 Visual Studio 中验证：

- 打开 `Apps\PaperPulseWindows\PaperPulse.Windows.sln`。
- 选择 x64 Debug。
- Restore 成功。
- F5 可以启动空白 `PaperPulse Windows` shell。
- MSIX packaging 配置可识别。

Phase 0 通过后，在 Windows 上提交一个本地提交，例如：

```powershell
git status --short
git add docs/development/windows-primary-development-handoff.md Apps/PaperPulseWindows
git commit -m "chore: validate windows phase 0 scaffold"
```

如果没有改文件，不需要强行提交；可以只把验证结果写入一个新的文档提交，例如：

```text
docs/development/windows-phase0-validation.md
```

该验证文档建议记录：

```text
Windows version:
Visual Studio version:
.NET SDK version:
Developer Mode:
WebView2 Runtime:
build.ps1 result:
test.ps1 result:
package.ps1 result:
Visual Studio F5 result:
Known issues:
```

## 后续阶段由 Windows 主机推进

### Phase 1：模型契约

目标：

- 在 `PaperPulse.Contracts` 中建立 C# records、enums、JSON contract。
- 以 Swift `Sources/PaperCore/Models.swift` 和 `Tests/PaperCoreTests/Fixtures/selected_manifest_sample.json` 为行为规范。
- 先写 C# fixture round-trip 测试，再实现模型。

不得做：

- HTTP 检索。
- PDF 下载。
- LLM provider。
- SQLite。
- PasswordVault。
- WinUI 完整界面。

Phase 1 完成标准：

- C# contract tests 通过。
- JSON 字段命名、默认值、向后兼容行为与 Swift 基线一致。
- 没有引入 Windows UI 或存储依赖到 `Contracts`。

### Phase 2：Storage 与 Credential

目标：

- SQLite schema。
- 文件目录策略。
- PDF 与完整解读文件保存策略。
- `PasswordVault` API key 适配。

必须保留：

- API key 不进 SQLite。
- API key 不进日志。
- API key 不进 JSON 导出。
- macOS Keychain 不自动迁移到 Windows。

### Phase 3：资料库与订阅 UI

目标：

- Windows 三栏或侧栏布局。
- 订阅编辑。
- 手动纸飞机推送。
- 论文按订阅分组、未归类分组、折叠状态、收藏、搜索。

必须保留：

- 第一版不恢复自动后台推送。
- 只有收藏，不新增已读分类。
- 选择订阅时自动展开该订阅并折叠其他组。

### Phase 4：PDF 与完整解读

目标：

- WebView2 本地 PDF 阅读。
- PDF/解读 1:1 并排。
- 分栏比例持久化。
- PDF 文本抽取 spike。
- 完整解读异步生成。

必须保留：

- 未配置 API key 时明确提示配置 API。
- 不用本地摘要冒充完整解读。
- 生成期间用户仍可浏览其他论文。
- 删除完整解读必须确认，且只删除当前论文的 Markdown 文件。

### Phase 5：发布与 CI

目标：

- GitHub Actions `windows-latest`。
- restore/build/test/package。
- x64 MSIX。
- 签名与安装验证。

不得做：

- 未签名包公开发布。
- 未在干净 Windows VM 验证就发布。
- 把未打包 WinUI 当作单文件 exe 交付。

## Windows 主开发期间的 Git 策略

建议：

- 继续使用 `codex/paperpulse-windows-migration` 作为迁移开发分支。
- 每个阶段至少一个提交。
- 每个阶段提交前运行可用测试。
- 阶段未完成时不合并到 `main`。
- 不要 rebase 掉 handoff/transfer/scaffold 提交。

推荐提交粒度：

```text
docs: record windows phase 0 validation
feat: add windows contract models
test: add windows JSON fixture contracts
feat: add windows sqlite migrations
feat: add windows credential vault adapter
feat: add windows library shell
feat: add windows pdf viewer
ci: add windows build workflow
```

推送策略：

- 本地开发可以频繁提交。
- 需要跨设备或备份时，推送 `codex/paperpulse-windows-migration`。
- 发布或 PR 前再整理 commit/说明。

## Mac 这边后续只负责什么

Mac 仍然有价值，但不是 Windows 主开发机。

Mac 可负责：

- 维护 Swift `PaperCore` 行为基线。
- 跑 `swift test`。
- 跑 macOS tests。
- 审阅 Windows 迁移是否偏离产品契约。
- 更新 handoff 文档。
- 对比 Swift fixtures 和 C# fixtures。

Mac 不负责：

- WinUI 3 运行验证。
- Windows App SDK 运行时验证。
- WebView2 PDF 行为验证。
- MSIX 打包安装验证。
- PasswordVault 验证。
- Windows 本地路径和权限验证。

## 必须保留的产品契约

Windows 端必须与现有 macOS 行为一致：

- 每个订阅由用户手动点击纸飞机推送论文。
- 同一论文可属于多个订阅，但元数据、PDF 与完整解读各只保存一份。
- 论文库按订阅分组，未归类单独成组。
- 各组可折叠。
- 选择订阅时自动展开该订阅，折叠其他订阅和未归类。
- 只有收藏，不引入已读分类。
- 机构、期刊/会议为空表示任意，但权威性筛选依然执行。
- 完整解读异步生成。
- 未配置 API key 时必须明确提示配置 API。
- 不使用本地摘要冒充完整解读。
- 生成期间在简介区域显示进行中状态，用户仍可浏览其他论文。
- 完整解读与 PDF 默认 1:1 并排。
- 分栏比例持久化。
- 删除完整解读必须确认，且只删除当前论文的解读文件。
- 界面语言与简介语言各自保存、互不绑定。

## 绝对不要做的事

不要：

- 把 macOS app 直接编译到 Windows。
- 把 Windows 做成 SwiftUI、SwiftData、PDFKit、AppKit 或 Keychain 兼容层。
- 让 C# WinUI app 长期依赖 Swift `PaperCore` 作为运行时。
- 读取 macOS SwiftData store。
- 自动迁移 macOS Keychain API keys。
- 把 API key 写进 SQLite、日志、导出 JSON、测试 fixture 或截图。
- 在 Phase 0/1 提前实现下载、LLM、PDF 文本抽取或完整 UI。
- 在未签名、未验证前公开发布 Windows 安装包。
- 让 `Engine` 引用 WinUI。
- 让 `Contracts` 引用 WinUI、SQLite 或文件系统。
- 让 UI code-behind 承载检索、存储、排序或 LLM 业务规则。

## Windows 主机遇到问题时如何回报

每个问题请记录为：

```text
Stage:
Command:
Expected:
Actual:
Exit code:
Windows version:
Visual Studio version:
dotnet --info:
Relevant file:
Suspected cause:
Minimal proposed fix:
```

如果 Codex 在 Windows 上修复了问题，提交信息应说明问题和范围，例如：

```text
fix: correct windows app manifest packaging metadata
fix: align windows sdk target framework
test: cover windows module dependency boundaries
docs: record windows phase 0 validation blockers
```

## 交接完成后的推荐第一步

在 Windows 主开发机上第一件事不是写业务代码，而是验证 Phase 0：

```powershell
git checkout codex/paperpulse-windows-migration
git status --short --branch
cd Apps\PaperPulseWindows
dotnet --info
.\scripts\build.ps1 -Configuration Debug
.\scripts\test.ps1 -Configuration Debug
.\scripts\package.ps1
```

只有这些通过，才进入 Phase 1。
