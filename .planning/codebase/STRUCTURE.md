# Codebase Structure

**Analysis Date:** 2026-09-05

## Directory Layout

```
imagi/
├── App/                         # Shared iPhone, iPad, and Mac application source
├── Sources/StudioCore/          # Provider-neutral domain types and real HTTP adapters
├── Tests/StudioCoreTests/       # Cross-platform package tests with mocked networking
├── NativeTests/                 # Apple-framework persistence and image-store tests
├── Configuration/               # Entitlement output created by XcodeGen
├── doc/adr/                     # Architecture decision records and index
├── .planning/codebase/          # Generated codebase mapping documents
├── Package.swift                # Local StudioCore Swift package manifest
├── project.yml                  # XcodeGen app targets, settings, and native test scheme
└── README.md                    # Setup, behavior, privacy, and verification guidance
```

## Directory Purposes

**`App/`:**
- Purpose: Hold all Apple-platform application composition, views, workflow state, local models, storage, credentials, and native services.
- Contains: SwiftUI views, `StudioModel`, SwiftData models, `ImageStore`, Keychain code, Photos/notification/haptic bridges, and the privacy manifest.
- Key files: `App/ImageStudioApp.swift`, `App/StudioModel.swift`, `App/Models.swift`, `App/ImageStore.swift`, `App/StudioView.swift`, `App/GalleryViews.swift`, `App/ImageViewer.swift`

**`Sources/StudioCore/`:**
- Purpose: Keep request/domain logic and provider networking independent of SwiftUI and SwiftData.
- Contains: Provider IDs, ratios, options, request validation, shared errors, service routing, and OpenAI/xAI adapters.
- Key files: `Sources/StudioCore/Generation.swift`, `Sources/StudioCore/Providers.swift`

**`Tests/StudioCoreTests/`:**
- Purpose: Verify shared request formatting, routing, validation, decoding, safe errors, and cancellation without paid calls.
- Contains: XCTest package tests, a recording provider, and mock `URLProtocol`.
- Key files: `Tests/StudioCoreTests/ProviderTests.swift`

**`NativeTests/`:**
- Purpose: Verify behavior that requires SwiftData, CoreGraphics, ImageIO, and Apple SDKs.
- Contains: In-memory persistence tests and temporary-filesystem image tests.
- Key files: `NativeTests/LocalLibraryTests.swift`

**`.planning/codebase/`:**
- Purpose: Store the generated architecture and repository navigation map.
- Contains: Markdown analysis documents.
- Key files: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`

**`doc/adr/`:**
- Purpose: Record why the current architecture was selected and its trade-offs.
- Contains: Five numbered ADRs and an index. Accepted records describe the implemented baseline, not verified release readiness.
- Key files: `doc/adr/README.md`, `doc/adr/0001-shared-native-apple-targets.md`, `doc/adr/0003-local-library-and-refinement-links.md`.

## Key File Locations

**Entry Points:**
- `App/ImageStudioApp.swift`: `@main` application, model container, environment injection, root tabs, and default Mac size.
- `App/StudioView.swift`: User entry into original generation and reference-based refinement.
- `App/GalleryViews.swift`: History/Favorites screens and reusable image action entry points.
- `App/ImageViewer.swift`: Full-image inspection and refinement ancestry traversal.

**Configuration:**
- `project.yml`: XcodeGen definitions for separate iPhone, iPad, Mac, and native-test targets.
- `Package.swift`: StudioCore package product and package test target.
- `App/PrivacyInfo.xcprivacy`: Application privacy manifest.
- `.gitignore`: Excludes SwiftPM, generated Xcode project, derived data, and local IDE artifacts.

**Core Logic:**
- `App/StudioModel.swift`: End-to-end workflow coordination and mutable studio state.
- `Sources/StudioCore/Generation.swift`: Stable request model, validation, errors, and provider interface.
- `Sources/StudioCore/Providers.swift`: Real OpenAI/xAI endpoint request and response handling.
- `App/Models.swift`: SwiftData generation and image metadata.
- `App/ImageStore.swift`: Full PNG and thumbnail filesystem persistence.
- `App/CredentialStore.swift`: Per-provider Keychain persistence.
- `App/NativeActions.swift`: Photos export and platform lifecycle feedback.

**Testing:**
- `Tests/StudioCoreTests/ProviderTests.swift`: Linux-capable unit tests for provider and service behavior.
- `NativeTests/LocalLibraryTests.swift`: Mac test bundle for metadata persistence, refinement links, cropping, thumbnails, and cleanup.

## Naming Conventions

**Files:**
- PascalCase Swift files generally match their main type or grouped responsibility: `StudioModel.swift`, `ImageStore.swift`, `ImageViewer.swift`.
- Plural filenames group closely related definitions: `Models.swift`, `Providers.swift`, `GalleryViews.swift`, `NativeActions.swift`.
- Test files end in `Tests.swift`: `ProviderTests.swift`, `LocalLibraryTests.swift`.

**Directories:**
- Swift Package Manager uses standard target paths: `Sources/StudioCore/` and `Tests/StudioCoreTests/`.
- Apple application and Apple-only tests use top-level PascalCase directories: `App/`, `NativeTests/`.
- Planning and decision documentation uses hidden/lowercase paths: `.planning/codebase/`, `doc/adr/`.

## Where to Add New Code

**New Feature:**
- Primary code: Put Apple UI and workflow additions in `App/`; put provider-neutral generation behavior in `Sources/StudioCore/`.
- Tests: Put transport/domain tests in `Tests/StudioCoreTests/`; put SwiftData, image-processing, or other Apple-SDK tests in `NativeTests/` and include needed app sources in `project.yml`.

**New Component/Module:**
- Implementation: Add reusable SwiftUI components beside `App/GalleryViews.swift` or the owning feature view; add new package types under `Sources/StudioCore/` when they must not depend on app frameworks.

**Utilities:**
- Shared helpers: Provider-independent helpers belong in `Sources/StudioCore/`; platform service wrappers belong in focused files under `App/`, following `CredentialStore.swift` and `NativeActions.swift`.

## Special Directories

**`.build/`:**
- Purpose: Swift Package Manager build database, compiled modules, and test products.
- Generated: Yes
- Committed: No; excluded by `.gitignore`.

**`.planning/codebase/`:**
- Purpose: Human-readable map of the current repository architecture and structure.
- Generated: Yes, by the codemap workflow.
- Committed: Repository policy is not stated; the directory was created for the current request.

**`doc/adr/`:**
- Purpose: Record architecture decisions separately from descriptive codebase maps.
- Generated: No
- Committed: No at mapping time; these records are new documentation in the working tree.

**`App/`:**
- Purpose: One shared source tree compiled into all three platform app targets declared in `project.yml`.
- Generated: No
- Committed: Yes

**`Sources/StudioCore/`:**
- Purpose: Local Swift package target also consumed by the app and both test layers.
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-09-05*
