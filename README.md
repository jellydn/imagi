# Welcome to Image Studio 👋

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-F05138?logo=swift&logoColor=white)](https://swift.org)
[![iOS 17+](https://img.shields.io/badge/iOS-17+-000000?logo=apple&logoColor=white)](https://www.apple.com/ios/)
[![macOS 14+](https://img.shields.io/badge/macOS-14+-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![AGENTS.md](https://img.shields.io/badge/AGENTS.md-supported-green)](./AGENTS.md)
[![Twitter: jellydn](https://img.shields.io/twitter/follow/jellydn.svg?style=social)](https://twitter.com/jellydn)

> A native SwiftUI image studio for iPhone, iPad, and Mac. Describe → generate variants → compare → refine → save.

Three app targets share `App/` and the local `StudioCore` Swift package. Each app keeps its own local library and API keys. There is no iCloud sync, analytics, or app backend.

Built and maintained by [@jellydn](https://github.com/jellydn).

## Features

- **Create, History, Favorites, Settings** — native tabs on iPhone, iPad, and Mac
- **Wide layout** — side-by-side composer and two-column comparison on iPad/Mac; stacked layout in narrow windows
- **OpenAI** — `gpt-image-1` generations and multipart image edits
- **xAI** — `grok-imagine-image-2.0` generations and JSON image edits
- **Ratios** — 1:1, 4:3, 3:4, 16:9, 9:16. xAI gets the exact ratio. OpenAI uses a native size, then **center-crops** to the requested ratio (the saved file is the cropped image)
- **Local library** — SwiftData metadata, prompt search, favorites, parent-image links, PNG + thumbnails in Application Support
- **Export** — ShareLink, Photos, context menus, confirmed deletion
- **Credentials** — Keychain only. Defaults and notification choice live in preferences

**ChatGPT Plus/Pro and Grok consumer subscriptions are not API credentials.** This app does not use cookies, private endpoints, or subscription workarounds. Saving a key does not verify it; the first real request does. Each generation or edit can incur provider charges. There are no automatic paid retries.

## Prerequisites

- Xcode 16 or later
- iOS/iPadOS 17 and macOS 14
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [just](https://github.com/casey/just) — optional shortcuts (see [`justfile`](./justfile))
- A funded [OpenAI](https://platform.openai.com/api-keys) and/or [xAI](https://console.x.ai) API key

```sh
brew install xcodegen just
```

## Getting started

```sh
git clone https://github.com/jellydn/imagi.git
cd imagi
just generate   # xcodegen generate
just open
```

Select `ImageStudio-iPhone`, `ImageStudio-iPad`, or `ImageStudio-Mac`. Simulator and Mac builds do not need a signing team. Before a physical device, set your team and replace the example bundle IDs (`com.example.imagestudio.*`).

After you change `project.yml`, run `just generate` again. Do not edit `ImageStudio.xcodeproj` (generated, gitignored).

## First image

1. Open **Settings** and follow **Get API key** for your provider.
2. Enable API billing with that provider. Save the key in the app.
3. Open **Create**, enter a prompt, and choose 1–4 variants and a ratio.
4. Select **Generate**. Images are saved to History automatically.
5. Open a variant. Select **Refine** to use it as the reference, or use **Save to Photos** / **Share**.

**Regenerate** restores the original prompt, settings, and reference (for an edit). You still select **Generate** to confirm a new paid request.

## Development

```sh
just test                          # StudioCore package tests (no keys, no paid network)
just test-filter ProviderTests.testOpenAIGenerationUsesNativeSizeAndNumericCount
just native-test                   # macOS SwiftData + ImageStore
just build-iphone                  # iOS Simulator
just build-ipad
just build-mac
just prek                          # hooks on all tracked files
just prek-install                  # Git shims
```

`swift test` covers `StudioCore` only. It can run on Linux. It does not type-check Apple frameworks.

## Run tests

Shared package tests:

```sh
just test
# or: swift test
```

Apple image-storage and SwiftData tests (Mac):

```sh
just native-test
```

Equivalent `xcodebuild`:

```sh
xcodegen generate
xcodebuild test -project ImageStudio.xcodeproj -scheme ImageStudio-NativeTests \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Architecture

```
SwiftUI → StudioModel → ImageGenerationService → OpenAIProvider / XAIProvider
```

`StudioModel` stores successful generation metadata in SwiftData and image files through `ImageStore`. A refinement stores the selected image ID on a new generation; it never overwrites the original. Deleting a reference keeps descendants, but that edit cannot be regenerated until you pick a new reference. Empty generation rows can remain in History after the last image is deleted.

Keys stay in Keychain. Prompts and reference images go directly to the selected provider under its data policy.

| Layer       | Choice                                                                 |
| ----------- | ---------------------------------------------------------------------- |
| UI          | SwiftUI (`App/`)                                                       |
| Persistence | SwiftData (`cloudKitDatabase: .none`)                                  |
| Images      | PNG + `{name}.thumb.png` (max 640px) via `ImageStore`                  |
| Keys        | Keychain (`CredentialStore`)                                           |
| Core        | local Swift package `StudioCore`                                       |
| Project     | XcodeGen (`project.yml`)                                               |
| Tasks       | [just](https://github.com/casey/just) · [prek](https://prek.j178.dev/) |

Agent notes: [`AGENTS.md`](./AGENTS.md).

## Background limits

Generation uses a cancellable URLSession request with a 300s timeout. iOS grants only limited background time. When that time expires, the app cancels the request and explains that the provider may still charge. Notifications are best-effort. Keep the app open for reliable generation.

## Provider references

- [OpenAI image generation and edits](https://platform.openai.com/docs/guides/image-generation)
- [xAI image generation](https://docs.x.ai/developers/model-capabilities/images/generation)
- [xAI image editing](https://docs.x.ai/developers/model-capabilities/images/editing)

Model availability depends on the API account and can change. OpenAI can require organization verification. Provider models live in `Sources/StudioCore/Generation.swift`; request formats live in `Providers.swift`.

## Author

👤 **Huynh Duc Dung**

- Website: [productsway.com](https://productsway.com/)
- Twitter: [@jellydn](https://twitter.com/jellydn)
- GitHub: [@jellydn](https://github.com/jellydn)

## Show your support

[![kofi](https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/dunghd)
[![paypal](https://img.shields.io/badge/PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://paypal.me/dunghd)
[![buymeacoffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/dunghd)

Give a ⭐️ if this project helped you!

[![Stargazers repo roster for @jellydn/imagi](https://reporoster.com/stars/jellydn/imagi)](https://github.com/jellydn/imagi/stargazers)

## License

This project is [MIT](./LICENSE) licensed.
