# Package Trigger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build mobile artifacts only on manual dispatch or `v*` version tags.

**Architecture:** Keep `test-android` as the mandatory validation job. Move
Android packaging to a conditional job and apply the same condition to iOS.

**Tech Stack:** GitHub Actions, Flutter 3.44.8.

## Global Constraints

- Ordinary push and pull request events must not build APK or IPA artifacts.
- Manual dispatch and `v*` tags must test before building both platforms.
- Preserve existing artifact names and build commands.

---

### Task 1: Gate Packaging Jobs

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `github.event_name`, `github.ref`, `test-android` result.
- Produces: `app-debug`, `ios-unsigned-ipa` artifacts.

- [x] Add `workflow_dispatch` and the `v*` tag filter.
- [x] Remove APK construction from the ordinary validation job.
- [x] Add conditional Android and iOS jobs depending on `test-android`.
- [ ] Push the workflow commit and verify branch push skips packaging.
- [ ] Push `v1.0.0` and verify tests plus both package jobs succeed.
- [ ] Download artifacts, sign the APK, and verify its certificate.
