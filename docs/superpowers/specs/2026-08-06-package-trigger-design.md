# Package Trigger Design

Ordinary branch pushes and pull requests run generation, analysis, and tests
only. Android APK and unsigned iOS IPA jobs run only for a manual
`workflow_dispatch` event or a pushed tag matching `v*`.

Packaging depends on the test job so artifacts are never produced from a
revision that failed analysis or tests. Existing artifact names and build
commands remain unchanged.
