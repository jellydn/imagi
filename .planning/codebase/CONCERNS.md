# Codebase Concerns

**Analysis Date:** 2026-09-05

This is a source review, not a device test or a release approval. Failure sequences below are inferred from code order unless stated otherwise. Suggestions are follow-up options, not newly accepted architecture decisions.

## Tech Debt

**Library metadata and image files have no reconciliation:**
- Issue: SwiftData stores filenames while `ImageStore` manages the files separately. Startup opens the model container but does not check for missing files or files with no model record.
- Files: `App/Models.swift`, `App/ImageStore.swift`, `App/ImageStudioApp.swift`, `App/GalleryViews.swift`
- Impact: An interrupted write, manual file loss, or a cross-store failure can leave unavailable gallery items or files that continue using storage but cannot be reached in the UI.
- Fix approach: Add a startup or maintenance reconciliation step. First test both directions with a temporary store: a model whose file is absent and a file whose model is absent.

**Provider contracts are encoded directly in request builders:**
- Issue: Endpoint paths, model names, request fields, and the exact expected response count are hard-coded.
- Files: `Sources/StudioCore/Generation.swift`, `Sources/StudioCore/Providers.swift`
- Impact: A provider contract or model-name change requires an app release and may turn otherwise usable responses into `invalidResponse`.
- Fix approach: Confirm each current contract against provider documentation and live sandbox calls, then isolate versioned provider details and record safe diagnostics that do not include prompts or images.

## Known Bugs

**A failed file deletion can leave a file with no library record:**
- Symptoms: The image disappears from SwiftData, an error alert appears, but its full image and thumbnail can remain on disk.
- Files: `App/StudioModel.swift`, `App/ImageStore.swift`
- Trigger: `StudioModel.delete` saves the model deletion first (`App/StudioModel.swift:121-124`); if either file removal then throws, `context.rollback()` runs after the model save and cannot reverse that committed save. `ImageStore.remove` can also remove the first path before failing on the second (`App/ImageStore.swift:52-56`).
- Workaround: None in the UI. Confirm with a native integration test that forces removal failure after `context.save()`, then define whether model deletion or file deletion is authoritative.

## Security Considerations

**Prompts and reference images leave the device:**
- Risk: The selected provider receives prompt text and, for edits, the complete reference image. xAI references are embedded as base64 in JSON; OpenAI references are multipart data.
- Files: `Sources/StudioCore/Providers.swift`, `App/PrivacyInfo.xcprivacy`
- Current mitigation: Requests use HTTPS, keys are stored in the data-protection Keychain, raw provider error bodies are not surfaced, and the privacy manifest declares no tracking.
- Recommendations: Verify the in-app disclosure and App Store privacy answers match actual provider transmission and retention. Whether this traffic belongs in `NSPrivacyCollectedDataTypes` is an unverified Apple policy question; check current Apple guidance rather than inferring it from source.

**Credential access remains available after first device unlock:**
- Risk: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` permits key access while the device is locked after its first unlock. This expands access beyond foreground-only generation.
- Files: `App/CredentialStore.swift`, `App/StudioModel.swift`
- Current mitigation: Credentials are device-only Keychain items, are not stored in preferences, and are only placed in HTTPS authorization headers by provider request builders.
- Recommendations: Confirm background generation needs locked-device access. If not, evaluate a stricter accessibility class and verify behavior on physical iOS and macOS devices.

## Performance Bottlenecks

**Generation and image saving hold several full-size representations in memory:**
- Problem: Large batches can temporarily retain response JSON, base64 text, decoded provider `Data`, decoded `CGImage` objects, and re-encoded PNG data.
- Files: `Sources/StudioCore/Providers.swift`, `App/ImageStore.swift`, `App/StudioModel.swift`
- Cause: `URLSession.data(for:)` buffers the whole response, `ImageResponse` decodes base64 for every item into an array, and `ImageStore.save` keeps the original response array alive while it decodes and re-encodes each image. Thumbnail creation now reuses the encoded PNG data instead of reading the just-written file.
- Improvement path: Measure peak memory for four maximum-size images on each Apple target. Then consider streamed/download responses where supported.

**Library search filters all fetched records in memory:**
- Problem: Every generation or favorite is fetched before prompt search is applied.
- Files: `App/GalleryViews.swift`
- Cause: `@Query` loads the collections and `filteredHistory` / `filteredFavorites` use Swift array filtering for each search update.
- Improvement path: Profile with a large seeded library, then move search filtering into a fetch predicate or add explicit pagination if measured UI latency is material.

## Fragile Areas

**Generation crosses network, files, and SwiftData without one transaction:**
- Files: `App/StudioModel.swift`, `App/ImageStore.swift`, `App/Models.swift`
- Why fragile: Success requires a provider response, optional reference read, batch image and thumbnail writes, model inserts, and a model save. Cleanup is best-effort (`try?`) and there is no durable operation journal if the process is terminated between steps.
- Safe modification: Preserve cancellation checks and batch file cleanup. Add fault-injection tests at each boundary before changing operation order, and add reconciliation for process termination cases.
- Test coverage: Shared tests cover request construction, response validation, routing, and cancellation. Native tests cover normal storage, cropping, metadata reload, and an invalid batch. They do not terminate the process or force SwiftData save and filesystem failures. Apple builds, UI, native integration, background execution, and live APIs remain unverified; 13 shared tests passed.

**Background completion is timing-dependent:**
- Files: `App/StudioModel.swift`, `App/NativeActions.swift`, `App/ImageStudioApp.swift`
- Why fragile: iOS background expiration cancels the task, but provider work may continue remotely and the local result is discarded. Completion notification is attempted only if `isBackgrounded` is true at the end and notification delivery errors are ignored.
- Safe modification: Treat cancellation as an uncertain remote outcome, retain the charge warning, and test foreground/background transitions and expiration on a physical device before changing this flow.
- Test coverage: No test exercises `UIApplication` background task identifiers, scene phase timing, notification permission, or notification delivery. This is unverified platform behavior, not a confirmed defect.

## Scaling Limits

**Local image library grows without a quota:**
- Current capacity: No count or byte limit is enforced; `byteCount()` reports current files only.
- Files: `App/ImageStore.swift`, `App/StudioModel.swift`, `App/GalleryViews.swift`
- Limit: Free device storage and SwiftData/gallery performance are the practical limits. Each generated image also has a thumbnail.
- Scaling path: Measure storage per four-image generation, surface low-space/write failures clearly, and add user-controlled bulk deletion or a retention policy before targeting large libraries.

**One generation can request at most four variants:**
- Current capacity: `ImageRequest.validate()` accepts 1-4 images and defaults are restricted to the same set.
- Files: `Sources/StudioCore/Generation.swift`, `App/SettingsView.swift`
- Limit: Requests outside that range fail locally even if a provider supports more.
- Scaling path: Treat this as a confirmed product implementation limit. If requirements change, verify each provider's current limits and memory/storage impact before changing validation.

## Dependencies at Risk

**OpenAI and xAI image API schemas:**
- Risk: The code assumes base64 responses, exact item counts, specific edit payload shapes, and fixed model identifiers. Unit tests validate these local assumptions but do not validate provider acceptance.
- Impact: Provider drift can stop generation or editing for one provider while the app reports a generic invalid-response or HTTP error.
- Migration plan: Run explicit live contract checks in non-production accounts, compare against current provider docs, and version request/response adapters. Live API compatibility is currently unverified.

**Apple-only app frameworks and generated project configuration:**
- Risk: SwiftData, Photos, UserNotifications, Security, UIKit/AppKit behavior and the privacy manifest are not exercised by the shared Linux package tests.
- Impact: Signing, entitlements, permissions, persistence migration, or platform UI issues can remain hidden despite shared test success.
- Migration plan: Generate the Xcode project and run iOS/macOS builds plus `ImageStudio-NativeTests` in supported Apple environments; then add device-level permission and lifecycle checks. No failure is confirmed from source alone.

## Missing Critical Features

**No library repair path:**
- Problem: The UI can show “Image unavailable,” but provides no scan or cleanup for broken model/file links and no way to remove unreachable orphan files.
- Files: `App/GalleryViews.swift`, `App/ImageStore.swift`, `App/ImageStudioApp.swift`
- Blocks: Recovery from interrupted cross-store operations without external container inspection. Next check: seed both inconsistency types and define a non-destructive repair policy.

**No persistence migration plan is visible:**
- Problem: The app creates one SwiftData schema directly and shows a generic failure screen if the container cannot open; no versioned schema or migration plan is defined.
- Files: `App/ImageStudioApp.swift`, `App/Models.swift`
- Blocks: Safe verification of future model changes. This does not prove the current schema fails. Next check: build an Apple-platform upgrade fixture before the first persisted-model change.

## Test Coverage Gaps

**Store failure ordering and recovery:**
- What's not tested: File-removal failure after a committed model deletion, SwiftData save failure after file writes, cleanup failure, missing files, orphan files, and process termination between these operations.
- Files: `App/StudioModel.swift`, `App/ImageStore.swift`, `App/Models.swift`, `NativeTests/LocalLibraryTests.swift`
- Risk: Data/file divergence and silent storage leaks can ship unnoticed.
- Priority: High

**Native permissions, lifecycle, and app launch:**
- What's not tested: Keychain behavior, Photos authorization/save, notifications, background expiration, scene transitions, persistent container launch failure/migration, and SwiftUI interactions.
- Files: `App/CredentialStore.swift`, `App/NativeActions.swift`, `App/ImageStudioApp.swift`, `App/GalleryViews.swift`
- Risk: Apple integration failures are not represented by the 13 passing shared tests. Native integration and UI remain unverified.
- Priority: High

**Live provider compatibility:**
- What's not tested: Real authentication, provider model availability, accepted generation/edit payloads, response formats, timeout behavior, rate limits, and billing/cancellation semantics.
- Files: `Sources/StudioCore/Providers.swift`, `Tests/StudioCoreTests/ProviderTests.swift`
- Risk: Mocked requests can pass while production APIs reject the request or return a supported shape the strict decoder rejects.
- Priority: High

**Large-library and high-memory behavior:**
- What's not tested: Peak memory for four full-size responses, low-disk writes, and search/scroll behavior with many generations.
- Files: `Sources/StudioCore/Providers.swift`, `App/ImageStore.swift`, `App/GalleryViews.swift`
- Risk: Termination, slow search, or failed saves may appear only with realistic image and library sizes.
- Priority: Medium

---

*Concerns audit: 2026-09-05*
