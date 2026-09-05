# Coding Conventions

**Analysis Date:** 2026-09-05

## Naming Patterns

**Files:**
- Swift files use UpperCamelCase names that usually match their main type or feature, such as `App/StudioModel.swift`, `App/ImageStore.swift`, and `Sources/StudioCore/Providers.swift`.
- Test files end in `Tests.swift`, as in `Tests/StudioCoreTests/ProviderTests.swift` and `NativeTests/LocalLibraryTests.swift`.

**Functions:**
- Functions and computed properties use lowerCamelCase. Action methods use verbs such as `generate`, `cancel`, `favorite`, `delete`, `save`, and `remove` in `App/StudioModel.swift` and `App/ImageStore.swift`.
- Test methods use XCTest's `test...` prefix and describe behavior, for example `testMissingKeyNeverCallsProvider` in `Tests/StudioCoreTests/ProviderTests.swift`.

**Variables:**
- Variables and properties use lowerCamelCase. Boolean state usually starts with `is`, `has`, or a state verb, such as `isGenerating`, `isBackgrounded`, `configured`, and `removing` in `App/StudioModel.swift` and `App/SettingsView.swift`.
- Short local names are used when their scope is narrow, such as `data`, `body`, `key`, and `ratio` in `Sources/StudioCore/Providers.swift`.

**Types:**
- Types and protocols use UpperCamelCase, including `StudioModel`, `ImageRequest`, `ImageGenerationProvider`, and `StudioError`.
- Enum cases use lowerCamelCase, including `openAI`, `xAI`, and `widescreen` in `Sources/StudioCore/Generation.swift`.

## Code Style

**Formatting:**
- No Swift formatter configuration was found. Sources show four-space indentation and opening braces on the declaration line.
- The code often keeps short declarations, branches, closures, and view modifiers on one line. Longer initializers, dictionaries, and SwiftUI modifier chains wrap over several lines, as seen in `App/StudioView.swift` and `Sources/StudioCore/Providers.swift`.
- Platform-specific code uses `#if os(iOS)`, `#if os(macOS)`, and `#if canImport(FoundationNetworking)` in place near the affected imports or statements.

**Linting:**
- No SwiftLint or other lint configuration was found. `Package.swift` and `project.yml` do not define lint phases.
- Strict compiler warnings have been used as verification: the previously reported shared-package command `swift test -Xswiftc -warnings-as-errors` passed 13 tests. This documents observed verification, not a new required rule.

## Import Organization

**Order:**
1. Apple framework imports appear first, usually beginning with the primary framework for the file, such as `SwiftUI`, `Foundation`, or `XCTest`.
2. Other Apple frameworks follow, such as `SwiftData`, `CoreGraphics`, `ImageIO`, and `Security`.
3. The local package import `StudioCore` follows framework imports in app and native-test files. Conditional platform imports follow the imports they support.

**Path Aliases:**
- No path aliases are used. The app imports the local Swift package as `StudioCore`, configured by `Package.swift` and `project.yml`.

## Error Handling

**Patterns:**
- Domain failures use the `LocalizedError` enum `StudioError` in `Sources/StudioCore/Generation.swift`; messages are suitable for display and provider HTTP response bodies are deliberately not exposed in `Sources/StudioCore/Providers.swift`.
- Validation uses `guard` followed by a thrown domain error. Fallible service, network, storage, Keychain, and persistence operations use `throws` and propagate errors with `try` or `try await`.
- UI boundaries catch errors and assign `error.localizedDescription` or a more specific message to `StudioModel.message`, as in `App/StudioModel.swift`, `App/GalleryViews.swift`, and `App/SettingsView.swift`.
- Persistence failures call `ModelContext.rollback()`. Multi-file saves remove partial output before rethrowing in `App/ImageStore.swift`; generation failure also removes already saved files in `App/StudioModel.swift`.
- Cancellation is checked explicitly with `Task.checkCancellation()` across network, image-storage, and UI-loading boundaries. Cancellation gets separate user-facing behavior in `App/StudioModel.swift`.
- Best-effort cleanup and notification work uses `try?` where failure should not replace the main outcome, in `App/StudioModel.swift`, `App/ImageStore.swift`, and `App/NativeActions.swift`.

## Logging

**Framework:** None observed

**Patterns:**
- No console, OSLog, or analytics logging is present in the inspected sources.
- Operational failures are surfaced through UI state. Sensitive provider response bodies are intentionally excluded from errors in `Sources/StudioCore/Providers.swift`.

## Comments

**When to Comment:**
- Comments explain non-obvious privacy, lifecycle, cleanup, or relationship behavior rather than restating code. Examples cover private provider bodies in `Sources/StudioCore/Providers.swift`, serial URL mocking in `Tests/StudioCoreTests/ProviderTests.swift`, and best-effort notifications in `App/NativeActions.swift`.
- Conditional compilation is mostly self-explanatory and is not accompanied by routine comments.

**JSDoc/TSDoc:**
- Not applicable to Swift. Swift documentation comments are rare; one `///` comment records the PNG normalization contract for `ImageRequest.referencePNG` in `Sources/StudioCore/Generation.swift`.

## Function Design

**Size:** Functions are generally focused on one operation. SwiftUI `body` builders and the generation workflow are longer because they compose UI or coordinate several stateful steps; examples are `App/StudioView.swift` and `App/StudioModel.swift`.

**Parameters:** Parameters use explicit domain types and external labels, such as `save(_:cropTo:)`, `generate(_:apiKey:)`, and `favorite(_:context:)`. Default arguments provide production dependencies or common values in `Sources/StudioCore/Providers.swift` and `App/ImageStore.swift`.

**Return Values:** Value-producing functions return concrete Swift values and throw on failure. Async I/O is marked `async throws`; UI action methods usually mutate observable state and return `Void`. Optional returns represent absence, such as a missing credential in `App/CredentialStore.swift`.

## Module Design

**Exports:** `Sources/StudioCore/` marks package API declarations and members `public`. App declarations remain internal. Implementation helpers such as response decoding and image conversion are `private`.

**Barrel Files:** No barrel or re-export files are used. `Package.swift` exposes one `StudioCore` library target, while app targets share the files under `App/` through `project.yml`.

---

*Convention analysis: 2026-09-05*
