# Release Guide

This guide covers the CI/CD pipeline and release process for Image Studio.

GitHub Releases ship the **Mac** app only (`ImageStudio-<version>.dmg` and `.zip`). iPhone and iPad targets still need Xcode, a signing team, and real bundle IDs.

## CI/CD Pipeline

- CI (`.github/workflows/ci.yml`) runs on `push` to `main` and all PRs: `swift test`, `xcodegen generate`, then `ImageStudio-NativeTests`.
- **Auto-release** (`.github/workflows/auto-release.yml`) runs on `push` to `main`:
  - If HEAD has no tag, it uses `MARKETING_VERSION` from `project.yml` for the first release, then increments the patch (for example `v1.0.0` → `v1.0.1`)
  - Updates `project.yml`, creates a Git tag, then calls the shared release workflow
- Manual release (`.github/workflows/release.yml`) builds and publishes on:
  - tag push: `v*` (example: `v1.0.0`)
  - manual dispatch with an existing `tag` input (example: `v1.0.0`)
- The shared release workflow builds and publishes unsigned Mac artifacts, then calls `update-appcast.yml` directly. This direct call is required because releases created with `GITHUB_TOKEN` do not start another workflow from a `release` event.

## Auto-Update (Mac)

The Mac app uses [Sparkle](https://sparkle-project.org/). Checks run on launch. Settings can turn automatic checks and downloads on or off.

The feed is `appcast.xml` at the repo root (`https://raw.githubusercontent.com/jellydn/imagi/main/appcast.xml`). `update-appcast.yml` signs the DMG with EdDSA after each GitHub Release.

The public EdDSA key is committed in `project.yml` as `SPARKLE_PUBLIC_ED_KEY`. Put its matching **private** key in the repository secret `SPARKLE_PRIVATE_KEY`. Never commit the private key. To replace the key pair, generate new keys with Sparkle `generate_keys`, update both locations together, and publish a new build.

## Creating a Manual Release

```sh
git tag v1.0.0
git push origin v1.0.0
```

The release uploads:

- `ImageStudio-<version>.dmg`
- `ImageStudio-<version>.zip`

Local unsigned assets:

```sh
just release-assets
# or: VERSION=1.0.0 BUILD_NUMBER=1 scripts/release/build-release-assets.sh
```

## No Apple Account Notes

- Artifacts are built unsigned (`CODE_SIGNING_ALLOWED=NO`).
- The app is not notarized.
- Users need to bypass Gatekeeper on first launch (Right-click app → Open).

> [!IMPORTANT] There is no Apple Developer signing on GitHub Releases. macOS may show that the app is from an unidentified developer.
>
> 1. Click **OK** to close the popup.
> 2. Open **System Settings** > **Privacy & Security**.
> 3. Scroll down and click **Open Anyway** next to the warning about the app.
> 4. Confirm your choice if prompted.
>
> You only need to do this once.
