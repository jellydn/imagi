# Architecture Decision Records

These records explain the implemented Image Studio MVP architecture in the `imagi` repository. They were written retrospectively on 2026-09-05 from the product requirements and current source. **Accepted** means part of that baseline; it does not mean Apple builds, device behavior, or live provider access have been verified.

Alternatives describe other approaches and their trade-offs. They are not a claim that those approaches were prototyped or measured.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-shared-native-apple-targets.md) | Shared native source with separate Apple app targets | Accepted |
| [0002](0002-official-provider-apis-and-keychain.md) | Official provider APIs with Keychain credentials | Accepted |
| [0003](0003-local-library-and-refinement-links.md) | Local metadata, image files, and refinement links | Accepted |
| [0004](0004-provider-specific-ratios-and-png-storage.md) | Provider-specific ratio handling and PNG storage | Accepted |
| [0005](0005-foreground-generation-and-explicit-retries.md) | Foreground generation with explicit paid retries | Accepted |

Read the [architecture map](../../.planning/codebase/ARCHITECTURE.md) for the current code flow, the [testing map](../../.planning/codebase/TESTING.md) for verification limits, and the [concerns map](../../.planning/codebase/CONCERNS.md) for follow-up risks.

When a decision changes, add a new numbered record and mark the old one as superseded with a link. Keep the earlier context and rationale. Proposed improvements in the concerns map are not accepted decisions.
