# Android Release Signing Design

## Goal

Generate every Android release APK with one long-lived private signing key so builds after the first signed installation can update the app in place.

## Design

- Keep the canonical keystore and recovery properties outside the public repository under `E:\novel-voice-reader\signing`.
- Configure `android/app/build.gradle.kts` to read the ignored `android/key.properties` file and sign only the release build type with its keystore.
- Keep the private key local. GitHub Actions continues to build `app-debug`; the downloaded APK is re-signed locally with Android `apksigner`.
- Preserve the existing CI workflow because the available GitHub credential cannot update workflow files.

## Security And Recovery

- Never commit `.jks`, `.keystore`, `key.properties`, passwords, or base64 key material.
- Restrict the local signing directory ACL to the current Windows user and administrators.
- Do not upload the keystore or password to any external service.
- Print and record the signing certificate SHA-256 fingerprint. Losing the keystore or password permanently prevents updating installed copies.

## Verification

- A configuration test must fail before the signing configuration exists and pass afterward.
- GitHub Actions must pass analysis, tests, and debug build.
- The downloaded release APK must pass ZIP structure checks and signing certificate inspection.
- The APK certificate SHA-256 fingerprint must match the local keystore certificate fingerprint.
