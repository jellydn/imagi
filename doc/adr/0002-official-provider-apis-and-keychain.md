# 0002. Use official provider APIs and Keychain credentials

Date: 2026-09-05

## Status

Accepted — records the implemented MVP baseline and the explicit provider constraint.

## Context

The product connects to OpenAI and Grok/xAI, but consumer subscriptions do not fund API use. ChatGPT subscriptions and OpenAI API billing are separate. OpenAI documents ChatGPT sign-in for its Codex clients, but it does not document that flow as third-party authentication for the image API. Grok and the xAI API can share an account, but their billing is separate. The xAI API uses team-bound keys and credits managed through the xAI Console. Prompts and reference images are private user content, and provider keys must not be stored in preferences or embedded in the application.

OpenAI and xAI have different image-edit request formats. Their authentication and model capabilities can change independently of the studio UI.

## Decision

- Require user-supplied official API keys. Explain before key entry that both providers require API billing or credits separate from consumer subscriptions.
- Do not use consumer-session cookies, private endpoints, another application's OAuth client, or undocumented subscription workarounds. Neither provider documents a general subscription OAuth client-registration flow for this native image app.
- Define a `Sendable ImageGenerationProvider` protocol and route requests with `ImageGenerationService` in `Sources/StudioCore/Generation.swift`. Each call selects one provider.
- Implement direct HTTPS requests with `URLSession` in `Sources/StudioCore/Providers.swift`. OpenAI uses JSON generation requests and multipart edits; xAI uses JSON for both and embeds a PNG data URI for edits.
- Store separate provider keys in the data-protection Keychain through `App/CredentialStore.swift`. Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; after first unlock, credentials can remain accessible during the limited background execution window. Store only non-secret preferences in UserDefaults.
- Report a stored key as **Key saved**, not as a verified connection. Saving does not make a paid request. Generation performs the actual access check.
- Do not expose raw provider error bodies. `StudioError` supplies safe HTTP and validation messages. The app has no account system, analytics service, or application-operated backend.

**Alternatives not selected:** A backend proxy would add server operations and place user credentials or provider billing under app-operator control. Consumer-session reuse violates the supported-access requirement. Provider SDKs would add dependencies for a small HTTP interface. A stricter Keychain accessibility class remains an option if locked-device access is no longer needed; it has not been compared on devices.

## Consequences

### Positive

- Credentials stay in Apple-managed secure storage rather than preferences or source.
- Provider-specific request formats stay behind one shared interface.
- Users retain control of their API accounts, provider choice, and billing.

### Negative

- Users always need an API key and provider API funds. Consumer subscriptions do not cover these API requests.
- Model availability, rate limits, and provider schema changes can require app updates. Current model identifiers are fixed in `Sources/StudioCore/Generation.swift`.
- Prompts and reference images leave the device under the selected provider's policy. Keychain does not protect content after transmission; privacy disclosures need review before release.
- Device-only key storage does not provide credential sync. After-first-unlock access is less restrictive than access only while unlocked.
- `Tests/StudioCoreTests/ProviderTests.swift` verifies local request construction and mocked responses, not live provider acceptance or physical-device Keychain behavior.
