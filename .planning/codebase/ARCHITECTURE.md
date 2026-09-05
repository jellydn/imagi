# Architecture

**Analysis Date:** 2026-09-05

## Pattern Overview

**Overall:** Native SwiftUI application with an observable presentation model, SwiftData metadata, actor-isolated file storage, and a provider-strategy networking package.

**Key Characteristics:**
- `App/ImageStudioApp.swift` builds the persistence container and injects one `StudioModel` into all four tab navigation stacks.
- `App/StudioModel.swift` owns the create workflow and coordinates credentials, provider calls, files, and SwiftData transactions on the main actor.
- `Sources/StudioCore/Generation.swift` defines provider-neutral requests and routing; `Sources/StudioCore/Providers.swift` contains the real OpenAI and xAI HTTP adapters.
- Metadata and image bytes have separate persistence owners: SwiftData models in `App/Models.swift`, PNG files and thumbnails in `App/ImageStore.swift`.
- SwiftUI views query persistent records directly while sending mutations through `StudioModel`.

## Layers

**Application Composition:**
- Purpose: Start the app, open local persistence, inject shared state, and select top-level screens.
- Location: `App/ImageStudioApp.swift`
- Contains: `ImageStudioApp`, `RootView`, tab routing, theme constants, and persistence-open fallback UI.
- Depends on: SwiftUI, SwiftData, `GenerationRecord`, `ImageAsset`, `StudioModel`, and feature views.
- Used by: The iPhone, iPad, and Mac application targets declared in `project.yml`.

**Presentation and Interaction:**
- Purpose: Render creation, history, favorites, settings, image actions, and lineage navigation.
- Location: `App/StudioView.swift`, `App/GalleryViews.swift`, `App/ImageViewer.swift`, `App/SettingsView.swift`
- Contains: SwiftUI screens, adaptive grids, search, sheets, dialogs, and bindings to shared state.
- Depends on: `StudioModel`, SwiftData queries and context, `ImageStore`, and native actions.
- Used by: `RootView` and nested navigation or presentation flows.

**Workflow State:**
- Purpose: Hold transient studio state and make generation, refinement, reuse, favorite, cancel, and delete operations coherent.
- Location: `App/StudioModel.swift`
- Contains: Main-actor observable state and orchestration methods.
- Depends on: `StudioCore`, `CredentialStore`, `ImageStore`, `NativeActions`, and SwiftData `ModelContext`.
- Used by: Views through SwiftUI's environment.

**Domain and Provider Boundary:**
- Purpose: Define request options, validation, provider selection, errors, and external HTTP request formats.
- Location: `Sources/StudioCore/Generation.swift`, `Sources/StudioCore/Providers.swift`
- Contains: `ProviderID`, `AspectRatio`, `GenerationOptions`, `ImageRequest`, `StudioError`, `ImageGenerationProvider`, service routing, and OpenAI/xAI implementations.
- Depends on: Foundation and `URLSession`; it does not depend on SwiftUI or SwiftData.
- Used by: `App/StudioModel.swift`, `App/Models.swift`, and `App/ImageStore.swift`.

**Local Persistence:**
- Purpose: Persist searchable generation metadata and image files independently.
- Location: `App/Models.swift`, `App/ImageStore.swift`
- Contains: SwiftData entities, relationships, PNG normalization, OpenAI ratio cropping, thumbnail creation, reads, deletion, and storage accounting.
- Depends on: SwiftData for metadata and ImageIO/CoreGraphics for files.
- Used by: `StudioModel`, `LocalImage`, gallery and viewer queries, settings, and native export.

**Platform Services:**
- Purpose: Isolate Keychain, Photos, haptic, background-time, and notification APIs.
- Location: `App/CredentialStore.swift`, `App/NativeActions.swift`
- Contains: Provider-key CRUD and Apple-platform side effects.
- Depends on: Security, Photos, UserNotifications, and UIKit where available.
- Used by: `StudioModel`, `SettingsView`, and gallery actions.

## Data Flow

**Real Image Generation:**
1. `App/StudioView.swift` binds prompt, provider, count, ratio, and optional reference to `StudioModel`, then calls `generate(context:)`.
2. `App/StudioModel.swift` snapshots those inputs, reads the selected provider key from `App/CredentialStore.swift`, and reads reference PNG bytes from `ImageStore` when refining.
3. `Sources/StudioCore/Generation.swift` validates the prompt, variant count, reference bytes, and key, then routes the request through `ImageGenerationService`.
4. `Sources/StudioCore/Providers.swift` sends a real `URLSession` POST directly to OpenAI or xAI. OpenAI uses JSON for generation and multipart form data for edits; xAI uses JSON and embeds edit input as a PNG data URI.
5. `Sources/StudioCore/Providers.swift` requires exactly the requested number of nonempty base64-decoded payloads. Image-format validation occurs later in `App/ImageStore.swift`. Raw provider error bodies are not surfaced.
6. `App/ImageStore.swift` validates each image, center-crops OpenAI output when needed, writes a full PNG and a thumbnail with a maximum dimension of 640 pixels, and returns generated filenames. Each file write is atomic; the pair is not one atomic operation.
7. `App/StudioModel.swift` inserts one `GenerationRecord` and its `ImageAsset` rows, saves the SwiftData context, and exposes the record as the current canvas. No successful metadata is inserted before all provider output files are saved.

**Persistence and Relaunch:**
1. `App/ImageStudioApp.swift` opens a local SwiftData `ModelContainer` for `GenerationRecord` and `ImageAsset` with CloudKit disabled.
2. `App/Models.swift` stores prompt, provider/model, ratio, requested count, timestamp, optional parent image UUID, filename, variant index, and favorite state.
3. Full images and thumbnails live under the private Application Support `ImageStudio/Images` directory managed by `App/ImageStore.swift`; SwiftData stores only filenames.
4. `@Query` properties in `App/StudioView.swift`, `App/GalleryViews.swift`, and `App/ImageViewer.swift` restore and react to metadata. `LocalImage` loads file bytes asynchronously.
5. A failed batch attempts to remove partial files. A later SwiftData save failure rolls back metadata and attempts to remove all files saved for that batch in `App/StudioModel.swift`. Cleanup uses `try?`; these stores do not form one atomic transaction, and process termination can bypass cleanup.

**Refinement Link Traversal:**
1. Choosing Refine in `App/GalleryViews.swift` or `App/ImageViewer.swift` calls `StudioModel.refine(_:)`, which keeps the selected `ImageAsset` as the reference and restores its provider and ratio.
2. Generation snapshots that reference's UUID into `GenerationRecord.parentImageID`; this is a loose UUID link rather than a SwiftData relationship, so the original image is never overwritten and descendants survive parent deletion.
3. `App/ImageViewer.swift` resolves one step backward by matching `parentImageID` to an image UUID and resolves forward children by finding generations whose `parentImageID` equals the displayed image UUID.
4. Each selected parent or child becomes the viewer's current image, so repeated selections traverse a longer refinement chain one edge at a time.
5. Regenerate in `App/StudioModel.swift` restores a generation's prompt and options. For refinements it must resolve the recorded parent from all images; if that image was deleted, reuse stops with an explanatory message.

**Deletion:**
1. Image grids and the viewer ask for confirmation before calling `StudioModel.delete(_:context:)` in `App/StudioModel.swift`.
2. The model clears the active reference when it points at the target, deletes only the `ImageAsset`, and saves SwiftData before removing the full PNG and thumbnail.
3. Deleting an image does not delete its `GenerationRecord` and does not follow loose `parentImageID` links to descendants. Therefore empty generation records and refinements with missing references remain visible or navigable as metadata.
4. If metadata or file removal throws, the context is rolled back and an error is shown. Because metadata is saved before file removal, a file-removal failure can leave an unreferenced local file even though the image row is already deleted.

**Responsive Layout Ownership:**
1. `App/StudioView.swift` owns the main composer/canvas breakpoint. At 760 points or wider it renders a fixed-width composer beside the canvas; below 760 it stacks both in one scroll view.
2. The same view chooses composer width at 1,000 points and derives wide-layout result tile height from available geometry.
3. `ImageGrid` in `App/GalleryViews.swift` owns collection responsiveness: callers can force a column count, while library grids use adaptive 170-to-360-point columns.
4. `App/GalleryViews.swift` owns platform-specific viewer presentation: full-screen on iOS and a minimum-size sheet on macOS.
5. `App/ImageViewer.swift` owns image fit/enlarge height relative to its own geometry. `App/ImageStudioApp.swift` owns only the default Mac window size.

**State Management:**
- Shared transient state is a single `@MainActor @Observable StudioModel` injected by `App/ImageStudioApp.swift`.
- Durable metadata is fetched with SwiftData `@Query`; writes use the environment `ModelContext` passed into model actions.
- Image file I/O is serialized outside the main actor by the `ImageStore` actor.
- Preferences use `UserDefaults`/`@AppStorage`, while API credentials use Keychain.

## Key Abstractions

**StudioModel:**
- Purpose: Present one mutation boundary for the studio workflow and its user-visible status.
- Examples: `App/StudioModel.swift`
- Pattern: Main-actor observable presentation model and async transaction coordinator.

**ImageGenerationProvider:**
- Purpose: Hide provider-specific transport behind one asynchronous generation operation.
- Examples: `Sources/StudioCore/Generation.swift`, `Sources/StudioCore/Providers.swift`
- Pattern: Strategy protocol selected by `ImageGenerationService`.

**GenerationRecord and ImageAsset:**
- Purpose: Separate one provider request's metadata from its ordered output images and favorite state.
- Examples: `App/Models.swift`
- Pattern: SwiftData parent-child relationship with cascade only from generation to its owned image rows; refinement ancestry is a separate UUID reference.

**ImageStore:**
- Purpose: Own image validation, normalized files, thumbnails, cleanup, and storage accounting.
- Examples: `App/ImageStore.swift`
- Pattern: Shared actor repository over the application-support filesystem.

**ImageGrid and LocalImage:**
- Purpose: Reuse asynchronous local image rendering and image actions across current results, history, and favorites.
- Examples: `App/GalleryViews.swift`
- Pattern: Composed SwiftUI presentation components backed by environment state and SwiftData queries.

## Entry Points

**Application Launch:**
- Location: `App/ImageStudioApp.swift`
- Triggers: Apple launches any app target generated from `project.yml`.
- Responsibilities: Open SwiftData, inject `StudioModel`, install tint, create tabs, track background state, and show global messages.

**Generate or Refine:**
- Location: `App/StudioView.swift`
- Triggers: The user selects Generate or Refine after entering a non-empty prompt.
- Responsibilities: Gather bound options and hand the current `ModelContext` to `StudioModel.generate(context:)`.

**Provider Request:**
- Location: `Sources/StudioCore/Providers.swift`
- Triggers: `ImageGenerationService.generate` selects OpenAI or xAI.
- Responsibilities: Encode the request, call the public provider endpoint, enforce HTTP and response-shape checks, and decode image bytes.

**Library and Viewer:**
- Location: `App/GalleryViews.swift`, `App/ImageViewer.swift`
- Triggers: History/Favorites tab selection or opening a grid image.
- Responsibilities: Query persisted content, search and display it, navigate refinement links, and expose favorite/export/refine/reuse/delete actions.

## Error Handling

**Strategy:** Validate before paid network work, treat each generated batch as an application-level transaction, and translate expected failures into user-facing messages.

**Patterns:**
- `StudioError` in `Sources/StudioCore/Generation.swift` gives safe messages for validation, credentials, common HTTP statuses, and malformed responses.
- `App/StudioModel.swift` uses `do/catch`, SwiftData rollback, and file cleanup; cancellation receives a separate notice that provider charges may still apply.
- `App/ImageStore.swift` attempts best-effort removal of files created by a partially failed batch.
- `App/ImageStudioApp.swift` replaces the app UI with a storage-safe explanation if the model container cannot open.
- `LocalImage` in `App/GalleryViews.swift` converts missing or undecodable local files into an inline unavailable state.

## Cross-Cutting Concerns

**Logging:** No application logging or analytics layer is present. `Sources/StudioCore/Providers.swift` deliberately avoids exposing raw provider response bodies because they may contain private data.

**Validation:** `ImageRequest.validate()` in `Sources/StudioCore/Generation.swift` checks prompt, count, and reference bytes. `App/ImageStore.swift` validates decoded images and output encoding. UI controls also constrain counts and disable generation for blank prompts.

**Authentication:** User-supplied provider API keys are stored per provider in the device Keychain by `App/CredentialStore.swift` and sent as bearer tokens directly to the selected provider. There is no user-account system, application backend, or cloud sync.

---

*Architecture analysis: 2026-09-05*
