# Unsigned IPA Artifact Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and deliver an unsigned release IPA for local ESign signing.

**Architecture:** Extend the existing macOS GitHub Actions job to build an
unsigned release app, package the Xcode output in the standard IPA directory
layout, and upload it as a named artifact. Download and inspect the successful
artifact before delivery.

**Tech Stack:** Flutter 3.44.8, Xcode, GitHub Actions, macOS `ditto`

## Global Constraints

- Do not use or store signing certificates, provisioning profiles, Apple IDs,
  passwords, UDIDs, or signing secrets.
- The IPA must be a release build and remain unsigned.
- The artifact must contain `Payload/Runner.app`.

---

### Task 1: Build and deliver the unsigned IPA

**Files:**
- Modify: `.github/workflows/ci.yml`
- Test: GitHub Actions macOS `build-ios` job

**Interfaces:**
- Consumes: `build/ios/iphoneos/Runner.app` from Flutter's iOS release build
- Produces: `build/ipa/novel-voice-reader-unsigned.ipa` and the
  `ios-unsigned-ipa` Actions artifact

- [ ] **Step 1: Verify the current workflow has no unsigned IPA artifact**

Run:

```powershell
Select-String -Path .github/workflows/ci.yml -Pattern 'ios-unsigned-ipa'
```

Expected: no matches.

- [ ] **Step 2: Add the release build, IPA packaging, and artifact upload**

Replace the iOS debug build with:

```yaml
- run: flutter build ios --release --no-codesign
- name: Package unsigned IPA
  run: |
    mkdir -p build/ipa/Payload
    cp -R build/ios/iphoneos/Runner.app build/ipa/Payload/
    cd build/ipa
    ditto -c -k --sequesterRsrc --keepParent Payload novel-voice-reader-unsigned.ipa
- uses: actions/upload-artifact@v4
  with:
    name: ios-unsigned-ipa
    path: build/ipa/novel-voice-reader-unsigned.ipa
    if-no-files-found: error
```

- [ ] **Step 3: Validate and commit the workflow**

Run:

```powershell
git diff --check
Select-String -Path .github/workflows/ci.yml -Pattern 'ios-unsigned-ipa|Payload/Runner.app|--release --no-codesign'
git commit -am "ci: publish unsigned iOS IPA"
```

Expected: the workflow contains all three packaging contracts and the commit
succeeds.

- [ ] **Step 4: Push and verify GitHub Actions**

Run:

```powershell
git push
gh run watch <run-id> --exit-status
```

Expected: the `build-ios` job succeeds and uploads `ios-unsigned-ipa`.

- [ ] **Step 5: Download and inspect the IPA**

Run:

```powershell
gh run download <run-id> -n ios-unsigned-ipa -D <outputs-directory>
tar -tf <outputs-directory>/novel-voice-reader-unsigned.ipa
```

Expected: the downloaded file is non-empty and contains
`Payload/Runner.app/Info.plist`.

