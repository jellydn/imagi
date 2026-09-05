# 0003. Store the library locally with explicit refinement links

Date: 2026-09-05

## Status

Accepted — records the implemented MVP baseline, not approval of its recovery gaps.

## Context

Users need chronological history, favorites, generation settings, and backward navigation through refinements without overwriting previous images. The MVP calls for SwiftData metadata and locally stored images. Cloud sync is deferred.

Generation metadata is small and searchable. Image files are larger and must also be available to native sharing and Photos export.

## Decision

- Store `GenerationRecord` and `ImageAsset` in SwiftData, as defined in `App/Models.swift`. A generation holds prompt, provider, model, ratio, requested count, timestamp, and optional reference-image UUID. Each image holds a filename, index, timestamp, and favorite flag.
- Store PNG files and thumbnails in Application Support through the `ImageStore` actor in `App/ImageStore.swift`. SwiftData holds filenames, not image bytes. Disable CloudKit in `App/ImageStudioApp.swift`.
- Link refinements using `GenerationRecord.parentImageID`, a UUID rather than a cascade relationship. Every refinement creates new records and files. `App/ImageViewer.swift` resolves parents and children from image records.
- Delete individual image rows and their files after confirmation. Keep the generation metadata and descendant refinements. If a reference is deleted, `App/StudioModel.swift` rejects regeneration of that edit rather than silently switching to text-only generation.
- During generation, save all image files before inserting successful metadata. On failure, attempt file cleanup and context rollback. These operations are coordinated in `App/StudioModel.swift` but are not one atomic transaction across files and SwiftData.

**Alternatives not selected:** Storing image bytes with each database record would combine ownership but diverge from the requested initial file-storage approach. CloudKit or a remote library would add sync and conflict rules before the local loop is validated. Cascading refinement deletion would destroy later work when a reference is removed. Overwriting the reference would break backward navigation.

## Consequences

### Positive

- Completed images and metadata remain available offline on the device.
- Refinement preserves earlier results, and deleting a reference does not delete its descendants.
- File URLs work directly with native sharing. Thumbnail creation and file operations are isolated from the main actor.

### Negative

- There is no cross-device library sync, storage quota, or bulk repair workflow.
- Loose UUID links can point to a deleted reference. Empty generation metadata remains after the final image is deleted.
- Cleanup is best-effort. Process termination between file writes and metadata save can leave unreferenced files.
- Deletion currently commits metadata before removing files. If file removal fails, rollback cannot restore that committed row. The source-derived failure sequence and follow-up tests are in `.planning/codebase/CONCERNS.md`; this ADR does not treat that gap as desirable behavior.
- `NativeTests/LocalLibraryTests.swift` contains storage and relationship tests, but they have not run on a Mac. There is no test for interrupted writes or post-commit file-removal failure.
