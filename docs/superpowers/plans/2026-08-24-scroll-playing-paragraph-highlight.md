# Scroll Playing Paragraph Highlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在滚动模式中仅高亮真实正在朗读且与播放游标匹配的段落，暂停、停止和正文单击均不高亮。

**Architecture:** 阅读路由同时订阅 `PlaybackRuntime.cursorChanges` 与 `NovelAudioHandler.playbackState`，把真实 `playing` 布尔值作为 `ReaderPage.playbackActive` 传入。`ReaderPage` 保留现有点击中性逻辑，只移除滚动模式对播放游标背景的额外屏蔽。

**Tech Stack:** Flutter 3.44.8、Dart、audio_service `PlaybackState`、flutter_test、GitHub Actions

## Global Constraints

- 单击滚动模式正文不得产生背景、描边、涟漪或“从这里朗读”按钮。
- 双击正文继续使用现有 `PlaybackCursor(chapterId, paragraphIndex)` 精确起播。
- 仅 `playing == true` 且播放游标匹配时使用现有 `paper.highlightWash`。
- 暂停、停止或仅存在历史游标时不得高亮。
- 不改动分页模式原有选择与播放行为。
- 按用户要求不运行本地验证，红绿验证和全量验证均使用 GitHub Actions CI。

---

### Task 1: ReaderPage 播放高亮回归测试

**Files:**
- Test: `test/features/reader/reader_page_test.dart:409`

**Interfaces:**
- Consumes: `ReaderPage.playbackCursor: PlaybackCursor?` 与 `ReaderPage.playbackActive: bool`
- Produces: 滚动模式真实播放高亮、游标转移和暂停清除高亮的行为契约

- [ ] **Step 1: Write the failing widget test**

将现有 `tracks playback without highlighting paragraphs in scroll mode` 改为 `highlights only the currently playing paragraph in scroll mode`，保留 StatefulBuilder 并加入以下断言：

```dart
expect(
  _paragraphBackground(tester, chapterId: 10, index: 0),
  PaperPalette.highlightWash,
);

setHostState(() {
  playbackCursor = const PlaybackCursor(chapterId: 10, paragraphIndex: 1);
});
await tester.pumpAndSettle();
expect(_paragraphBackground(tester, chapterId: 10, index: 0), isNull);
expect(
  _paragraphBackground(tester, chapterId: 10, index: 1),
  PaperPalette.highlightWash,
);
```

再令宿主传入可变的 `playbackActive`，将其切换为 `false` 后断言游标仍存在但背景为空：

```dart
setHostState(() => playbackActive = false);
await tester.pump();
expect(_paragraphBackground(tester, chapterId: 10, index: 1), isNull);
```

- [ ] **Step 2: Commit and push the failing test**

```powershell
git add -- test/features/reader/reader_page_test.dart
git commit -m "test(reader): require active playback paragraph highlight"
git push origin codex/fix-playback-chapter-navigation
```

- [ ] **Step 3: Verify RED in GitHub Actions**

```powershell
gh run list --branch codex/fix-playback-chapter-navigation --workflow ci.yml --limit 1
gh run watch <run-id> --interval 10 --exit-status
```

Expected: `flutter test` fails because the matching paragraph background is `null` while `PaperPalette.highlightWash` is expected. Confirm the failure is limited to the new expectation before implementing production code.

### Task 2: ReaderPage 恢复真实播放段落背景

**Files:**
- Modify: `lib/features/reader/presentation/reader_page.dart:792`
- Test: `test/features/reader/reader_page_test.dart:375`

**Interfaces:**
- Consumes: `widget.playbackActive` as actual handler `playing` state and `widget.playbackCursor`
- Produces: `playing` 为真且游标匹配时的 `paper.highlightWash` 背景

- [ ] **Step 1: Remove only the scroll-mode playing-highlight suppression**

保持 `allowSelection = !scrollMode`、`NoSplash` 和透明 overlay 不变，只让播放背景直接由 `playing` 决定：

```dart
final playing =
    widget.playbackActive &&
    widget.playbackCursor?.chapterId == paragraph.chapterId &&
    widget.playbackCursor?.paragraphIndex == paragraph.index;
final allowSelection = !scrollMode;

// ...

color: playing
    ? paper.highlightWash
    : active
    ? scheme.surfaceContainerHigh
    : null,
```

同步修正注释，明确滚动模式屏蔽的是点击选择反馈，而非当前朗读背景。

- [ ] **Step 2: Preserve the click-neutral regression assertions**

确认 `tapping a paragraph in scroll mode never highlights it` 仍断言：

```dart
expect(paragraphInkWell.splashFactory, same(NoSplash.splashFactory));
expect(
  paragraphInkWell.overlayColor?.resolve({WidgetState.pressed}),
  Colors.transparent,
);
expect(find.byKey(const ValueKey<String>('active-paragraph-101')), findsNothing);
expect(find.text('从这里朗读'), findsNothing);
```

- [ ] **Step 3: Commit the ReaderPage implementation**

```powershell
git add -- lib/features/reader/presentation/reader_page.dart test/features/reader/reader_page_test.dart
git commit -m "fix(reader): highlight the actively narrated paragraph"
```

### Task 3: 阅读路由订阅真实播放状态

**Files:**
- Modify: `lib/app/router.dart:224-390`
- Test: `test/app/navigation_test.dart:105`

**Interfaces:**
- Consumes: `PlaybackRuntime.handler.playbackState.value.playing` and `Stream<PlaybackState>`
- Produces: `_playbackPlaying: bool` passed as `ReaderPage.playbackActive`

- [ ] **Step 1: Extend the navigation test to cover pause and resume**

在 `shows playback highlight when opening an already playing book` 中读取段落容器背景；启动后断言为 `PaperPalette.highlightWash`，调用 handler 暂停后断言背景为空，再调用 handler 播放并断言背景恢复：

```dart
expect(
  _playingParagraphBackground(tester, chapter.id, 0),
  PaperPalette.highlightWash,
);
await runtime.handler.pause();
await tester.pump();
expect(_playingParagraphBackground(tester, chapter.id, 0), isNull);
await runtime.handler.play();
await tester.pump();
expect(
  _playingParagraphBackground(tester, chapter.id, 0),
  PaperPalette.highlightWash,
);
```

测试辅助函数只查找 `playing-paragraph-$chapterId-$paragraphIndex` 下带 `BoxDecoration` 的容器并返回颜色，不引入生产代码测试入口。

- [ ] **Step 2: Subscribe to handler playback state beside the cursor stream**

在 `_ReaderRoutePageState` 增加：

```dart
StreamSubscription<bool>? _playbackPlayingSubscription;
bool _playbackPlaying = false;
```

`dispose()` 中取消订阅；`_observePlaybackRuntime` 切换 runtime 时同时取消旧订阅、从当前 value 初始化，并订阅去重后的真实状态：

```dart
unawaited(_playbackPlayingSubscription?.cancel());
_playbackPlaying = runtime?.handler.playbackState.value.playing ?? false;
_playbackPlayingSubscription = runtime?.handler.playbackState
    .map((state) => state.playing)
    .distinct()
    .listen((playing) {
      if (mounted && generation == _playbackSubscriptionGeneration) {
        setState(() => _playbackPlaying = playing);
      }
    });
```

把 ReaderPage 参数由游标存在性改为真实状态：

```dart
playbackCursor: _playbackCursor,
playbackActive: _playbackPlaying,
```

- [ ] **Step 3: Commit the route wiring**

```powershell
git add -- lib/app/router.dart test/app/navigation_test.dart
git commit -m "fix(reader): drive highlight from playback state"
```

### Task 4: CI 绿灯与交付

**Files:**
- Verify only: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: Tasks 1-3 commits
- Produces: GitHub Actions full test evidence

- [ ] **Step 1: Push the completed implementation**

```powershell
git push origin codex/fix-playback-chapter-navigation
```

- [ ] **Step 2: Verify GREEN in GitHub Actions**

```powershell
gh run list --branch codex/fix-playback-chapter-navigation --workflow ci.yml --limit 1
gh run watch <run-id> --interval 10 --exit-status
gh run view <run-id> --json status,conclusion,headSha,url,jobs
```

Expected: `dart run build_runner build`、`flutter analyze`、`flutter test` 均成功，run `conclusion` 为 `success`，`headSha` 等于最终提交。

- [ ] **Step 3: Report behavior and CI evidence**

交付时明确说明：播放中当前段落显示暖色背景；暂停、停止和正文单击不显示；双击起播逻辑未改变。附最终提交和 GitHub Actions URL。
