# Image Studio

A native SwiftUI image studio for iPhone, iPad, and Mac. Describe → generate variants → compare → refine → save.

## Open on a Mac

Requires Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen). Minimum OS versions: iOS/iPadOS 17 and macOS 14.

```sh
brew install xcodegen
xcodegen generate
open ImageStudio.xcodeproj
```

Select `ImageStudio-iPhone`, `ImageStudio-iPad`, or `ImageStudio-Mac`. Set your signing team and replace the example bundle identifiers before running on a physical device. Simulator builds do not need a team. The three app targets share `App/` and the local `StudioCore` Swift package. They have separate local libraries and credentials; iCloud sync is not included.

## First image

1. Open Settings and follow **Get API key** for your provider.
2. Enable API billing with that provider. Save the key in the app.
3. Open Create, enter a prompt, and choose 1–4 variants and a ratio.
4. Select Generate. Images are saved to History automatically.
5. Open a variant. Select Refine to use it as the reference, or use Save to Photos / Share.

**ChatGPT Plus/Pro and Grok consumer subscriptions are not API credentials.** This app does not use browser cookies, private endpoints, or subscription workarounds. A saved key is not reported as verified until a real request succeeds. Each generation/edit can incur provider charges. There are no automatic paid retries. Regenerate restores the original prompt, settings, and reference (for an edit); the user selects Generate to confirm a new request.

## Included

- Native Create, History, Favorites, and Settings tabs.
- Side-by-side composer and two-column comparison grid on wide iPad/Mac windows; stacked layout in narrow windows.
- OpenAI `gpt-image-1` generations and multipart image edits.
- xAI `grok-imagine-image-2.0` generations and JSON image edits.
- Ratios 1:1, 4:3, 3:4, 16:9, and 9:16. xAI receives the exact ratio. OpenAI uses a supported native size and **center-crops** to the requested ratio, as shown in the composer. Cropping can remove edge detail; the saved image is the cropped version.
- SwiftData metadata, prompt search, favorites, timestamps, and parent-image links. The viewer can go back to the reference or forward to its refinements.
- PNG files and smaller gallery thumbnails in Application Support. Image normalization, cropping, and disk work run outside the main actor. Failed batches clean up their files.
- iOS full-screen viewer and Mac viewer sheet; fit/enlarge, native ShareLink, Photos export, context menus, and confirmed deletion.
- Keychain credentials, per-device defaults, storage size, iOS haptics, optional background completion notifications.
- Loading, cancellation, missing-key, provider-error, empty-gallery, unavailable-image, and persistence-open-error states.

## Architecture

`SwiftUI → StudioModel → ImageGenerationService → ImageGenerationProvider → OpenAIProvider / XAIProvider`

`StudioModel` stores successful generation metadata in SwiftData and image files through `ImageStore`. A refinement stores the selected image ID on its new generation; it never overwrites the original. Deleting a reference keeps its descendants, but that edit can no longer be regenerated from the missing reference. Empty generation metadata remains in History after its last image is deleted.

Keys stay in Keychain. Preferences contain only defaults and notification choice. The app has no analytics or application backend. Prompts and reference images are sent directly to the selected provider under its data policy. Review the privacy manifest and App Store privacy answers against your final distribution and the providers' current terms.

## Verification

Checked in the Linux orb with Swift 6.0.3:

- `swift test`: 13 tests passed, 0 failures.
- Swift syntax parsing for both iOS and macOS conditional branches: passed. This is not Apple SDK type-checking.
- Project YAML and privacy property list parsing: passed.
- Apple builds, three native tests, rendered UI, Photos/Keychain integration, and live API generation: not run; require a Mac and, for generation, a funded API account.

Shared package tests (no keys, no paid network calls):

```sh
swift test
```

Apple image-storage and SwiftData tests:

```sh
xcodegen generate
xcodebuild test -project ImageStudio.xcodeproj -scheme ImageStudio-NativeTests \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Build all app targets on a Mac:

```sh
xcodebuild -project ImageStudio.xcodeproj -scheme ImageStudio-iPhone \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ImageStudio.xcodeproj -scheme ImageStudio-iPad \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ImageStudio.xcodeproj -scheme ImageStudio-Mac \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Before release, run these device checks:

- Generate four variants with each provider; confirm the grid, saved dimensions, and actual image content.
- Refine twice, navigate back and forward, relaunch, and confirm history/favorites remain.
- Check narrow iPhone, iPad split view, and Mac windows in light/dark mode and large text. Use VoiceOver on prompt controls, image actions, and errors.
- Export to Photos with permission allowed and denied; share to Files and one installed messaging app.
- Try an invalid key, no credit, offline mode, cancellation, and background expiration. Confirm that failed requests do not create empty successful generations.
- Remove a key, relaunch, and confirm that the provider cannot generate without reconfiguration.
- Add final app icons and distribution signing before App Store submission.

The Linux orb can run the shared Swift package and parse Swift syntax. It cannot type-check Apple frameworks, run the Apple tests, render SwiftUI, or produce a signed app. Live generation also needs your funded API account. These Apple/device and live-provider checks must be completed before release.

## Background limits

Generation uses a cancellable foreground URLSession request with up to five minutes of request timeout. iOS grants only limited background execution time. When that time expires, the app cancels the request and explains that the provider may still charge. Notifications are best-effort and only fire if generation completes while the process can still run. There is no guarantee of completion after suspension or force-quit. Keep the app open for reliable generation.

## Provider references

- [OpenAI image generation and edits](https://platform.openai.com/docs/guides/image-generation)
- [xAI image generation](https://docs.x.ai/developers/model-capabilities/images/generation)
- [xAI image editing](https://docs.x.ai/developers/model-capabilities/images/editing)

Model availability depends on the API account and can change. OpenAI can require organization verification. Provider models are isolated in `Sources/StudioCore/Generation.swift`; request formats are in `Providers.swift`.
