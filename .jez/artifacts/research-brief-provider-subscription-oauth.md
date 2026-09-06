# Research Brief: Provider Subscription OAuth

**Depth**: Wide
**Date**: 2026-09-06

## Executive Summary

Image Studio cannot safely add a general “Sign in with ChatGPT” or “Sign in with Grok” flow for image generation. OpenAI documents ChatGPT sign-in for OpenAI's Codex clients, while its public API authentication uses API keys or workload identity tokens. xAI documents API-key authentication for Imagine. Grok and the xAI API can share an account, but API billing is separate and managed through the xAI Console.

The correct fix is clearer product guidance, not an undocumented OAuth implementation. The app must continue to use provider API keys stored in Keychain.

## Current Provider Behavior

| Provider | Consumer subscription | Public image API authentication | Result for Image Studio |
| --- | --- | --- | --- |
| OpenAI | ChatGPT Plus/Pro can include Codex access, but does not fund OpenAI API use | Bearer API key; workload identity is also available for suitable server workloads | Require a user API key and separate API billing |
| xAI | Grok subscription billing is separate from xAI API billing | Bearer API key associated with an xAI account and team | Require a user API key and API credits managed through the xAI Console |

## Why OAuth Is Not Implemented

### OpenAI

OpenAI's Codex documentation describes “Sign in with ChatGPT” for OpenAI-operated Codex surfaces such as the Codex app, CLI, and IDE extension. The general API reference does not publish a third-party authorization-code registration flow for a native image client. Reusing the OAuth client identifier or browser session of an OpenAI application would make this app depend on credentials and behavior that OpenAI did not issue to it.

ChatGPT Actions OAuth is the opposite trust direction: ChatGPT signs in to a developer's service. It does not let a native application use a ChatGPT subscription for the OpenAI image API.

### xAI

xAI documents bearer API keys for image generation. Its Accounts FAQ says Grok and the xAI API can share an account, but their billing is separate. API billing and credits are managed through the xAI Console. xAI does not publish a third-party Grok subscription OAuth client-registration flow for Imagine.

xAI connector OAuth is also the opposite trust direction: Grok connects to external services. It is not authentication from Image Studio to xAI.

## Options Considered

| Option | Decision | Reason |
| --- | --- | --- |
| Direct provider API keys in Keychain | Selected | Official for both image APIs; no app backend; user controls provider account and billing |
| Reuse consumer cookies or another application's OAuth client | Rejected | Undocumented, fragile, and unsafe; no client registration or support contract for this app |
| Add an Image Studio backend and proxy all requests | Rejected for the current product | Adds account, secret, billing, privacy, and operations responsibilities; it does not convert ChatGPT billing into API billing |
| Wait for provider-issued public OAuth registration | Monitor | Valid only if a provider publishes a supported native-app flow and scopes for its image API |

## Implemented Product Correction

- OpenAI copy now states that ChatGPT and API billing are separate and that documented ChatGPT sign-in is specific to Codex clients.
- xAI copy now states that Grok subscription billing and xAI API billing are separate and that API credits are managed through the xAI Console.
- Error text now says that the provider image APIs do not offer subscription OAuth to this app.
- Architecture and credential storage remain unchanged.

## Risks and Open Questions

- Provider plans, model access, and billing rules can change without an app release.
- A saved key does not prove model access. Only a real request can validate it, and that request can incur a charge.
- If either provider publishes native third-party OAuth for image API scopes, review token refresh, Keychain storage, callback handling, account switching, revocation, and migration before implementation.

## Sources

### OpenAI

- [Codex authentication](https://developers.openai.com/codex/auth)
- [OpenAI API authentication overview](https://developers.openai.com/api/reference/overview/)
- [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)
- [ChatGPT and API billing are separate](https://help.openai.com/en/articles/9039756)

### xAI

- [xAI developer quickstart](https://docs.x.ai/developers/quickstart)
- [Grok and xAI API accounts and billing FAQ](https://docs.x.ai/console/faq/accounts)
