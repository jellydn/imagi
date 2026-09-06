# Technology Stack

**Analysis Date:** 2026-09-05

## Languages

**Primary:**
- Swift 5.9 package syntax - Shared models, provider clients, app logic, native UI, and tests in `Package.swift`, `Sources/StudioCore/`, `App/`, `Tests/StudioCoreTests/`, and `NativeTests/`.

**Secondary:**
- YAML - XcodeGen project, target, scheme, entitlement, and generated Info.plist configuration in `project.yml`.
- XML property list - App privacy declarations in `App/PrivacyInfo.xcprivacy`.

## Runtime

**Environment:**
- Native Apple application runtime on iOS/iPadOS 17 or later and macOS 14 or later, declared in `Package.swift` and `project.yml`.
- Swift concurrency is used for provider calls, cancellation, file work, and UI coordination in `Sources/StudioCore/Providers.swift`, `App/ImageStore.swift`, and `App/StudioModel.swift`.

**Package Manager:**
- Swift Package Manager through the local `StudioCore` package in `Package.swift`; the app consumes that package by local path in `project.yml`.
- Lockfile: missing; `Package.swift` declares no third-party package dependencies.

## Frameworks

**Core:**
- SwiftUI - Shared native UI and three-platform app entry in `App/ImageStudioApp.swift`, with views under `App/`.
- SwiftData - Local generation and image metadata models and persistence in `App/Models.swift` and `App/ImageStudioApp.swift`.
- Foundation and URLSession - JSON, multipart HTTP requests, response decoding, and async networking in `Sources/StudioCore/Providers.swift`.
- Security - Per-provider API key storage in the data-protection Keychain in `App/CredentialStore.swift`.
- CoreGraphics, ImageIO, and UniformTypeIdentifiers - PNG validation, center cropping, encoding, and thumbnail creation in `App/ImageStore.swift`.
- Photos, UserNotifications, and UIKit - Photo export, completion notifications, iOS haptics, and background task time in `App/NativeActions.swift`.

**Testing:**
- XCTest - 13 shared package tests for request construction, validation, routing, decoding, HTTP failures, and cancellation in `Tests/StudioCoreTests/ProviderTests.swift`.
- XCTest with SwiftData and Apple image frameworks - Three native persistence and image-store tests in `NativeTests/LocalLibraryTests.swift`, configured by `project.yml`.

**Build/Dev:**
- XcodeGen - Generates one Xcode project with three application targets and one macOS unit-test target from `project.yml`.
- Xcode 16 or later is the documented Apple build environment in `README.md`.
- Swift Package Manager can run the shared package tests from `Package.swift`; `README.md` records that 13 shared tests passed previously in a Linux orb, not an Apple build.

## Key Dependencies

**Critical:**
- `StudioCore` local Swift package - Owns generation types, validation, provider selection, provider models, and HTTP clients in `Package.swift` and `Sources/StudioCore/`.
- Apple SDK frameworks only - The package has no external package products in `Package.swift`, and app imports are native frameworks in `App/`.

**Infrastructure:**
- SwiftData local store - Persists `GenerationRecord` and `ImageAsset` with CloudKit explicitly disabled in `App/ImageStudioApp.swift`.
- Application Support files - Stores normalized PNG images and thumbnails under the app container in `App/ImageStore.swift`.
- UserDefaults via `@AppStorage` - Stores provider, variant, aspect-ratio, and notification preferences in `App/SettingsView.swift`; the matching required-access API reason is declared in `App/PrivacyInfo.xcprivacy`.

## Configuration

**Environment:**
- No environment variables are read; users enter official OpenAI or xAI API credentials in `App/SettingsView.swift`, and `App/CredentialStore.swift` stores them per provider in Keychain.
- ChatGPT Plus/Pro and Grok subscriptions do not fund provider API use. OpenAI and xAI API billing are managed separately through their developer platforms, as explained in `App/SettingsView.swift` and `README.md`.
- OpenAI uses model `gpt-image-1`; xAI uses `grok-imagine-image-2.0`, both centralized in `Sources/StudioCore/Generation.swift`.

**Build:**
- `project.yml` sets Swift 5.0 Xcode build mode, generated Info.plists, version 1.0.0 (build 1), photo-library usage strings, and user-script sandboxing.
- `project.yml` defines `ImageStudio-iPhone`, `ImageStudio-iPad`, and `ImageStudio-Mac`, all sharing `App/` and the local package in `Package.swift`.
- `project.yml` assigns separate bundle identifiers and device families; physical-device signing teams and production bundle identifiers are intentionally left for the developer, as documented in `README.md`.
- The Mac target supplies entitlement properties and the output path `Configuration/Mac.entitlements` in `project.yml`. XcodeGen writes that file during project generation and sets `CODE_SIGN_ENTITLEMENTS`; its absence before generation is not a missing-input blocker. See the [XcodeGen entitlement rules](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#target).
- Generated `*.xcodeproj` directories, SwiftPM build state, DerivedData, and user Xcode data are excluded by `.gitignore`.

## Platform Requirements

**Development:**
- A Mac with Xcode 16 or later and XcodeGen is required for Apple SDK type-checking, native tests, UI rendering, and app builds, per `README.md`.
- Swift Package Manager can build and test `StudioCore` from `Package.swift`; the previous result documented in `README.md` is 13 passing shared tests, not a fresh verification here.

**Production:**
- iPhone and iPad deployment target iOS/iPadOS 17.0, and Mac deployment target macOS 14.0, in `project.yml` and `Package.swift`.
- Distribution requires replacing example bundle identifiers, selecting a signing team, supplying final icons, and validating privacy answers, as listed in `README.md`.
- Apple builds and live OpenAI/xAI requests are not claimed as tested; `README.md` identifies both as outstanding Mac/account-dependent checks.

---

*Stack analysis: 2026-09-05*
