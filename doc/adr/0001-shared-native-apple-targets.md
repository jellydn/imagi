# 0001. Share native source across separate Apple app targets

Date: 2026-09-05

## Status

Accepted — records the implemented MVP baseline.

## Context

The requested app is an image studio, not a chat client. It must use Swift, SwiftUI, and SwiftData and support iPhone, iPad, and Mac with mostly shared source. The explicit platform request includes Mac now, although the supplied PRD also lists Mac as a later feature.

Native sharing, Photos, Keychain, and adaptive layouts are central to the product. Provider logic does not require Apple UI frameworks and should be testable separately.

## Decision

- Use the shared `App/` source tree for three application targets: `ImageStudio-iPhone`, `ImageStudio-iPad`, and `ImageStudio-Mac`. `project.yml` sets separate bundle identifiers, iOS device families, and minimum versions of iOS/iPadOS 17 and macOS 14.
- Use XcodeGen's `project.yml` as the project source of truth. The Xcode project is generated and excluded by `.gitignore`. XcodeGen also writes the Mac entitlement file from properties in `project.yml`.
- Keep provider types, validation, and HTTP code in the local `StudioCore` package declared in `Package.swift`. It depends on Foundation rather than SwiftUI or SwiftData.
- Compose the app in `App/ImageStudioApp.swift`; keep workflow state in the main-actor observable `App/StudioModel.swift`. Views query SwiftData directly and send library mutations through this model.
- Use geometry-based layout in `App/StudioView.swift`. Isolate platform differences in `App/NativeActions.swift` and viewer presentation in `App/GalleryViews.swift`.

**Alternatives not selected:** A web view or cross-platform JavaScript UI would not meet the requested stack. Separate UI implementations would duplicate the core loop. A single combined iOS target would reduce target configuration but would not follow the requested target separation. Keeping all logic in the app target would prevent Linux package tests from covering the provider boundary.

## Consequences

### Positive

- One set of screens and workflow code serves all three targets.
- Native controls and platform export APIs remain available.
- Shared provider tests run without Xcode, credentials, or paid network calls.

### Negative

- The three targets have separate app containers and no shared library or iCloud sync in this MVP.
- XcodeGen is a setup dependency. Signing, bundle identifiers, and app icons still need distribution configuration.
- SwiftData sets the minimum OS versions. Supporting earlier Apple OS releases would require a different persistence approach.
- Linux tests and syntax checks do not validate Apple SDK type-checking, SwiftUI layout, entitlements, or native behavior. `README.md` lists those outstanding checks.
