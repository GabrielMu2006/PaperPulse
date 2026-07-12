# PaperPulse Setup

## Already Downloaded Locally

- XcodeGen 2.45.4
  - Binary: `.tools/xcodegen-2.45.4/xcodegen/bin/xcodegen`
  - Generated project: `PaperPulse.xcodeproj`

Regenerate the Xcode project from `project.yml`:

```bash
./scripts/generate_project.sh
```

## Installed Toolchain

### 1. Full Xcode

The current machine has full Xcode 26.6 selected at `/Applications/Xcode.app/Contents/Developer`.

https://apps.apple.com/app/xcode/id497799835

Verify the selected installation with:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

If the selected path changes, run the `xcode-select` command above again.

### 2. iOS Simulator Runtime

The iOS 26.5 runtime and iPhone/iPad simulator devices are installed. To add another runtime:

- Xcode -> Settings -> Platforms -> iOS -> Download

If your Xcode version supports command-line runtime downloads, this may also work:

```bash
xcodebuild -downloadPlatform iOS
```

### 3. Apple Developer Signing

For simulator-only development, a paid team is not required.

For real device, TestFlight, APNs, BackgroundTasks production behavior, or macOS distribution:

- Sign in: Xcode -> Settings -> Accounts
- Add Apple ID / Apple Developer Team
- Use bundle IDs:
  - `com.gabrielmu.PaperPulse.iOS`
  - `com.gabrielmu.PaperPulse.macOS`

## API Keys To Prepare

Academic APIs:

- arXiv: no key required
- OpenAlex: no key required
- Crossref: no key required
- Unpaywall: use your email as the API email parameter
- Semantic Scholar: recommended API key from https://www.semanticscholar.org/product/api

LLM/search providers:

- OpenAI: https://platform.openai.com/api-keys
- Anthropic: https://console.anthropic.com/settings/keys
- Google Gemini: https://aistudio.google.com/apikey
- Perplexity: https://www.perplexity.ai/settings/api
- 阿里云百炼/Qwen: https://bailian.console.aliyun.com/
- 智谱 GLM: https://open.bigmodel.cn/usercenter/apikeys
- Kimi/Moonshot: https://platform.moonshot.cn/console/api-keys
- DeepSeek: https://platform.deepseek.com/api_keys

Keep API keys in Keychain through the app settings; do not commit keys into this repository.

## Relay / 中转站 Configuration

For GPT, Claude, and Gemini relay services:

1. Open Settings in PaperPulse.
2. Pick the provider family, for example `Claude / Anthropic` or `Gemini / Google`.
3. Set `API Style` to `OpenAI-compatible` if the relay exposes `/v1/chat/completions`.
4. Enter the relay `Base URL`, for example `https://relay.example.com/v1`.
5. Enter the relay model name exactly as the relay documents it, for example `claude-sonnet-4.5` or `gemini-2.5-pro`.
6. Save the relay API key.

For official APIs:

- GPT: `OpenAI-compatible`, base URL `https://api.openai.com/v1`
- Claude: `Anthropic Messages`, base URL `https://api.anthropic.com/v1`
- Gemini: `Gemini GenerateContent`, base URL `https://generativelanguage.googleapis.com/v1beta`
