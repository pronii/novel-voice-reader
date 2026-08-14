# Android Release Signing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce stable, update-compatible Android release APKs locally and in GitHub Actions.

**Architecture:** Gradle reads an ignored properties file for local release signing. GitHub Actions keeps the private key out of the runner, assigns a monotonically increasing build number, and uploads an unsigned universal APK that is signed locally.

**Tech Stack:** Flutter 3.44.8, Android Gradle Kotlin DSL, Java keytool, GitHub Actions

## Global Constraints

- Signing secrets must never enter Git history or command output.
- The application ID remains `com.pronii.novel_voice_reader`.
- Existing debug CI behavior remains available.
- Release `versionCode` uses `github.run_number`.

---

### Task 1: Guard The Signing Contract

**Files:** Create `test/android_release_signing_config_test.dart`.

- [ ] Assert Gradle uses an external release key and CI publishes `app-release-signed` with an increasing build number.
- [ ] Run the focused test and confirm it fails against the current debug signing configuration.

### Task 2: Configure Gradle And CI

**Files:** Modify `android/app/build.gradle.kts` and `.github/workflows/ci.yml`.

- [ ] Load ignored `android/key.properties` and create the Gradle release signing config.
- [ ] Build an unsigned release on push with `github.run_number` and no signing secrets.
- [ ] Upload `app-release-unsigned`, then run focused and full tests.

### Task 3: Provision And Verify The Signing Identity

**Files:** Create `E:\novel-voice-reader\signing\novel-voice-reader-release.jks` and `android-release-signing.properties` outside the repository.

- [ ] Generate a 4096-bit RSA key with a long random password and restrict local ACLs.
- [ ] Install Android build tools locally without disclosing the key.
- [ ] Push, wait for CI, download the unsigned APK, sign it locally, and compare its certificate SHA-256 fingerprint with the keystore.
