# Unsigned IPA Artifact Design

## Goal

Produce an unsigned release IPA from GitHub Actions that the user can sign
locally with ESign.

## Design

The existing macOS CI job will build the Flutter iOS application in release
mode with code signing disabled. It will then place `Runner.app` under the
standard `Payload` directory, create `novel-voice-reader-unsigned.ipa`, and
upload that file as a GitHub Actions artifact.

No Apple account, certificate, provisioning profile, device UDID, or signing
secret is used or stored. The resulting IPA is not directly installable until
the user signs it with ESign.

## Verification

GitHub Actions must complete the iOS release build, package a non-empty IPA,
and publish an unexpired `ios-unsigned-ipa` artifact. The downloaded archive
must contain `Payload/Runner.app`.

