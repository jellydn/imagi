# 0004. Adapt aspect ratios per provider and normalize local images to PNG

Date: 2026-09-05

## Status

Accepted — records the initial implementation choice and its visible crop trade-off.

## Context

The composer must offer 1:1, 4:3, 3:4, 16:9, and 9:16. The chosen OpenAI model's native sizes do not match every ratio; the xAI request format supports an aspect-ratio field. Refinement also needs a known input image format across providers.

## Decision

- Keep the five ratios in `AspectRatio` in `Sources/StudioCore/Generation.swift`.
- Map OpenAI requests to 1024×1024, 1536×1024, or 1024×1536. After generation, center-crop the saved image to the requested ratio in `App/ImageStore.swift`. The composer in `App/StudioView.swift` discloses cropping for non-square OpenAI output.
- Send xAI the selected `aspect_ratio` directly in `Sources/StudioCore/Providers.swift`. Do not apply an extra local crop to xAI output.
- Require the complete requested batch of nonempty base64-decoded payloads at the provider boundary. Validate actual image decoding in `ImageStore`, then encode stored images as PNG and create thumbnails with a maximum dimension of 640 pixels.
- Use these stored PNGs as refinement references. The original pre-crop provider file is not retained separately.

**Alternatives not selected:** Provider-specific ratio menus would expose fewer choices for OpenAI. Prompt-only ratio instructions would not ensure saved dimensions. Padding would keep edge content but add borders. Retaining both original and cropped images would allow later crop changes but require extra storage and UI. JPEG storage would be smaller in many cases but introduce a lossy step in repeated refinement.

## Consequences

### Positive

- Users get one ratio selector and a common local export/reference format.
- PNG storage avoids an additional lossy encoding step.
- Gallery thumbnails reduce the size of files loaded for comparisons.

### Negative

- Center cropping removes edge content and can change composition. Integer pixel rounding can make the saved ratio slightly approximate.
- The user cannot recover the pre-crop output from the app. Changing ratio during refinement can remove more content.
- PNG can use more storage than JPEG. Base64 responses, decoded data, full images, and re-encoded files increase peak memory during a batch.
- A partial or differently shaped provider response is rejected as a whole; provider charges may still apply. The xAI response dimensions are not independently checked against the requested ratio.
- Shared tests cover ratio mapping and response decoding. Native cropping tests exist in `NativeTests/LocalLibraryTests.swift`, but native tests, visual checks, and live provider checks remain outstanding.
