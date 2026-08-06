# TTS Provider Dropdown Design

## Goal

Replace the overflowing horizontal TTS provider selector with a narrow-screen-safe dropdown menu.

## Interaction

- Show one full-width field labelled `语音服务` at the top of the voice settings page.
- Display the active provider with its existing icon and label.
- Opening the field shows all six providers: 系统、兼容、Azure、智谱、腾讯云、MiMo.
- Selecting an item immediately updates the provider-specific form exactly as the segmented control does today.
- Remove the horizontal scroll container; no provider should require dragging or be partially clipped.

## Scope

- Change only provider selection UI and its widget tests.
- Keep provider values, save behavior, credentials, speed, connection tests, and page navigation unchanged.
- Verify the menu at a 320-pixel logical width and update existing tests to select providers through the dropdown.

