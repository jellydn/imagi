# External Integrations

**Analysis Date:** 2026-09-05

## APIs & External Services

**Image generation providers:**
- OpenAI Images API - Generates images and performs reference-image edits through `/v1/images/generations` and `/v1/images/edits` in `Sources/StudioCore/Providers.swift`.
- SDK/Client: Native `URLSession`; JSON is used for generation and multipart form data for edits in `Sources/StudioCore/Providers.swift`.
- Auth: A user-supplied official OpenAI API key is sent as a Bearer token; the key is entered in `App/SettingsView.swift` and read from Keychain by `App/CredentialStore.swift`.
- Model and sizing: `gpt-image-1` and supported native OpenAI sizes are selected in `Sources/StudioCore/Generation.swift`; non-square output is center-cropped locally by `App/ImageStore.swift`.
- xAI Images API - Generates images and performs JSON reference-image edits through `/v1/images/generations` and `/v1/images/edits` in `Sources/StudioCore/Providers.swift`.
- SDK/Client: Native `URLSession` with JSON request and base64 image response handling in `Sources/StudioCore/Providers.swift`.
- Auth: A user-supplied official xAI API key is sent as a Bearer token; the key is entered in `App/SettingsView.swift` and read from Keychain by `App/CredentialStore.swift`.
- Model and sizing: `grok-imagine-image-2.0` and exact requested aspect-ratio strings are defined in `Sources/StudioCore/Generation.swift`.
- Official API keys are required. ChatGPT Plus/Pro and OpenAI API billing are separate. Paid Grok plans can include a shared allowance that xAI reports with an API category, but xAI's documented developer flow still requires an API key and allowance is account- and plan-dependent. Provider-specific guidance and official account links are defined in `Sources/StudioCore/Generation.swift` and displayed by `App/SettingsView.swift`.
- Saved credentials are not preflight-verified; the first generation checks access and can incur provider charges, as explained in `App/SettingsView.swift` and `README.md`.

## Data Storage

**Databases:**
- Local SwiftData database for generation metadata, favorites, timestamps, model/provider settings, and parent-image relationships in `App/Models.swift`.
- Connection: App-container local persistence with CloudKit disabled in `App/ImageStudioApp.swift`; there is no remote database connection.
- Client: Apple SwiftData `ModelContainer` and `ModelContext` in `App/ImageStudioApp.swift` and `App/StudioModel.swift`.

**File Storage:**
- Local app-container Application Support storage for PNG images and thumbnails in `App/ImageStore.swift`; native sharing uses those local URLs in `App/GalleryViews.swift`.
- Apple Photos is an explicit export destination after add-only authorization in `App/NativeActions.swift`; it is not the primary app library.

**Caching:**
- No external cache service; smaller local thumbnail PNGs are generated and managed beside images in `App/ImageStore.swift`.

## Authentication & Identity

**Auth Provider:**
- No application user accounts or identity provider; the app sends credentials directly to the selected image provider according to `App/StudioModel.swift` and `Sources/StudioCore/Providers.swift`.
- Implementation: Separate OpenAI and xAI generic-password Keychain items use service `ImageStudio.ProviderAPIKey`, data-protection Keychain, and this-device-only accessibility in `App/CredentialStore.swift`.
- Implementation: Keys are entered through privacy-sensitive secure fields and can be replaced or removed in `App/SettingsView.swift`; preferences do not hold API keys.

## Monitoring & Observability

**Error Tracking:**
- None; the app states that it has no analytics or app-operated server in `App/SettingsView.swift` and `README.md`.

**Logs:**
- No logging service or explicit logging calls are present in `App/` or `Sources/StudioCore/`; user-safe localized errors are surfaced by `App/StudioModel.swift`.
- Raw provider response bodies are deliberately not surfaced because they may contain private data, as documented in `Sources/StudioCore/Providers.swift`.

## CI/CD & Deployment

**Hosting:**
- Native App Store-style applications rather than a hosted service; the three app targets and bundle identifiers are declared in `project.yml`.
- No app-operated backend is used, according to `App/SettingsView.swift` and `README.md`.

**CI Pipeline:**
- None is present in the repository; local SwiftPM and Xcode/XcodeGen verification commands are documented in `README.md`.
- `README.md` reports 13 shared package tests passed previously, while Apple builds, native Apple tests, and live provider generation were not run.

## Environment Configuration

**Required env vars:**
- None; there are no environment-variable reads in `App/` or `Sources/StudioCore/`.
- Runtime generation requires an official provider API key entered in `App/SettingsView.swift`. The app does not accept browser credentials or OAuth tokens. xAI decides whether a request uses eligible subscription allowance or separately purchased credit.

**Secrets location:**
- API keys are stored per provider in the Apple Keychain by `App/CredentialStore.swift`; no secret values are committed or documented.
- Provider preferences and notification choice use UserDefaults in `App/SettingsView.swift` and `App/StudioModel.swift`, while `App/PrivacyInfo.xcprivacy` declares the required UserDefaults API reason and declares no tracking domains or collected-data types.

## Webhooks & Callbacks

**Incoming:**
- None; no server or inbound endpoint exists in `App/`, `Sources/StudioCore/`, or `project.yml`.

**Outgoing:**
- Direct HTTPS requests to `api.openai.com` and `api.x.ai` are constructed in `Sources/StudioCore/Providers.swift`.
- No webhooks are emitted; local completion notifications are scheduled through `UNUserNotificationCenter` in `App/NativeActions.swift` when enabled through `App/SettingsView.swift`.
- Provider privacy and API-key management links are opened from `App/SettingsView.swift`; prompts and reference images follow the selected provider's policy as explained there.

---

*Integration audit: 2026-09-05*
