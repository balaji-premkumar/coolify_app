# Coolify Mobile

Android client for managing a self-hosted [Coolify](https://coolify.io) instance. You connect once with the site URL and an API token; the token is kept in the Android Keystore-backed secure storage and the app is gated by your device lock (biometrics or PIN) every time it opens or resumes. See `PLAN.md` for the roadmap.

## Develop

```
flutter pub get
flutter analyze && flutter test
flutter run
```

## Releases (CD)

Pushing a tag `vX.Y.Z` runs `.github/workflows/release-apk.yml`, which analyzes, tests, builds a signed release APK and publishes it as a **GitHub Release** – `coolify-mobile-X.Y.Z.apk` plus a `.sha256` file (easiest place to download from a phone).

The workflow can also be started manually (Actions → Release APK → Run workflow); it then only uploads a `-dev.N` build as a workflow artifact (no Release).

### One-time setup: signing key

Create a keystore (keep it and its passwords safe; losing it means users cannot update the app):

```
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias coolify
base64 -w0 release.jks   # value for ANDROID_KEYSTORE_BASE64
```

Add these repository secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 of `release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `coolify` (the alias used above) |
| `ANDROID_KEY_PASSWORD` | key password |

Then release with `git tag v0.1.0 && git push origin v0.1.0`. The build fails early with a clear message if the secrets are missing.
