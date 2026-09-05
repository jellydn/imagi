# Agent notes

Native SwiftUI Image Studio. Three app targets share `App/` plus local Swift package `StudioCore`. No iCloud, no analytics, no app backend.

## Commands

Do not edit or commit `*.xcodeproj`. It is generated and gitignored. Change `project.yml`, then run `just generate` (`xcodegen generate`).

`just` recipes: `test`, `test-filter FILTER`, `native-test`, `build-iphone` / `build-ipad` / `build-mac`, `release-assets`, `prek`.

CI (`macos-26`) runs `swift test` then NativeTests after `xcodegen generate`. Tag `v*` or merge to `main` publishes an unsigned Mac DMG/ZIP. Sparkle is Mac-only (`App/SparkleUpdater.swift`); keep `import Sparkle` behind `#if os(macOS)`. Public EdDSA key lives in `project.yml`; private key is the `SPARKLE_PRIVATE_KEY` GitHub secret. Do not commit the private key. See `RELEASES.md`.

```sh
swift test
swift test --filter ProviderTests.testOpenAIGenerationUsesNativeSizeAndNumericCount
```

`swift test` covers `StudioCore` only (no keys, no paid network). It can run on Linux. It does not type-check Apple frameworks.

On a Mac, after `xcodegen generate`:

```sh
xcodebuild test -project ImageStudio.xcodeproj -scheme ImageStudio-NativeTests \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

App schemes: `ImageStudio-iPhone`, `ImageStudio-iPad`, `ImageStudio-Mac`. Simulator/Mac builds use `CODE_SIGNING_ALLOWED=NO`. Device builds need a signing team and real bundle IDs (replace `com.example.imagestudio.*`).

## Layout

- `Sources/StudioCore/` — models, `ImageGenerationService`, OpenAI/xAI HTTP. Keep provider models in `Generation.swift`. Keep request formats in `Providers.swift`.
- `App/` — SwiftUI, `StudioModel`, SwiftData, `ImageStore`, Keychain, Photos. Shared by all three apps.
- `Tests/StudioCoreTests/` — package tests with `MockURLProtocol`. Serial mock; do not add parallel network tests against that mock.
- `NativeTests/` — macOS XCTest for SwiftData + `ImageStore`. The NativeTests target also compiles `App/Models.swift` and `App/ImageStore.swift` directly. Do not duplicate those types.

Flow: `SwiftUI → StudioModel → ImageGenerationService → OpenAIProvider / XAIProvider`.

SwiftData schema: `GenerationRecord` + `ImageAsset`. `cloudKitDatabase: .none`. Each app target has its own local library and credentials.

## Do not change without cause

- Keys stay in Keychain (`CredentialStore`). Preferences hold defaults and notification choice only. Saving a key does not verify it; the first real request does.
- ChatGPT Plus/Pro and Grok consumer subscriptions are not API credentials. Do not add cookie, private-endpoint, or subscription workarounds.
- No automatic paid retries. Cancel/timeout can still incur provider charges; keep that user copy.
- Do not log or surface raw provider HTTP bodies.
- OpenAI: native size (`openAISize`) then **center-crop** to the requested ratio. xAI: send `aspect_ratio` exactly; do not crop.
- A refinement stores `parentImageID` on a new record. It does not overwrite the original. Deleting a reference keeps descendants; regenerate of that edit then fails until the user picks a new reference. Empty generation rows can remain after the last image is deleted.
- Failed batches must not leave image files. `ImageStore` writes PNG + `{name}.thumb.png` (max 640px).
- Request timeout is 300s. iOS background time is limited; do not promise completion after suspend or force-quit.
- Linux tests import `FoundationNetworking` where needed. Do not remove that.
- Mac sandbox entitlements come from `project.yml` (`network.client`, Photos, user-selected files). There is no checked-in `.entitlements` file.
