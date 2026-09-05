# 0005. Use foreground generation with explicit paid retries

Date: 2026-09-05

## Status

Accepted — records the MVP execution model and its background limits.

## Context

Image generation can take minutes and can incur charges even if the client disconnects. The user needs progress, cancellation, and completion feedback. The MVP has no server job queue, and iOS does not guarantee continued execution after the app leaves the foreground.

## Decision

- Allow one active generation in `App/StudioModel.swift`. Snapshot prompt, settings, and reference at the start, then retain a cancellable Swift task in the observable model so switching tabs does not itself cancel work.
- Use `URLSession.data(for:)` with a 300-second request timeout in `Sources/StudioCore/Providers.swift`. This is not a durable or resumable background transfer.
- Request limited iOS background time through `App/NativeActions.swift`. Cancel when that time expires. Tell users to keep the app open and warn that cancellation can leave provider charges.
- Do not automatically retry paid requests. Regenerate restores the previous prompt, options, and reference when available; the user selects Generate to confirm another request.
- Use iOS haptics at start and successful completion. Attempt a local completion notification only when enabled and the model reports that the app is backgrounded after saving. Notification delivery is best-effort and does not change the saved result.

**Alternatives not selected:** A server-owned job queue could support result recovery after suspension but adds a backend, authentication, retention rules, and operations. A background URLSession transfer alone would not provide a provider job identifier or recover remote work after an uncertain outcome. Automatic retries can duplicate paid work when a request succeeds remotely but the client loses its response.

## Consequences

### Positive

- The MVP has a simple execution model without server infrastructure.
- Users control retries and can stop waiting without an automatic second charge attempt.
- Notification failure does not remove successful images from the local library.

### Negative

- Generation is not guaranteed to finish after suspension or force-quit. Results can be lost locally while work continues remotely.
- Request cancellation does not prove provider cancellation or a billing refund.
- There is no durable pending-job record, remote status polling, or resume operation.
- Scene-phase timing, background expiration, notification permissions, and Mac window behavior need native validation. `Tests/StudioCoreTests/ProviderTests.swift` covers an already-cancelled mocked request, not these lifecycle cases.
