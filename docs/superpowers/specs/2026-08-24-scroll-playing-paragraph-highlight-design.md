# 滚动模式当前朗读段落高亮设计

## 目标

滚动模式下，仅对当前真实正在朗读的段落做差异化显示。正文单击、暂停、停止或仅存在历史播放游标时，不显示段落级高亮。

## 方案

采用真实播放状态驱动高亮：阅读路由订阅音频处理器的 `playbackState`，将 `playing` 状态与现有 `PlaybackCursor(chapterId, paragraphIndex)` 一起传入 `ReaderPage`。段落仅在以下条件全部满足时使用现有 `paper.highlightWash` 背景：

- `playing == true`
- 播放游标非空
- 游标的 `chapterId` 与段落一致
- 游标的 `paragraphIndex` 与段落一致

不采用“游标非空即正在播放”的推断，因为暂停时游标仍会保留；也不采用游标变化瞬间的临时高亮，因为长段播放期间游标不会持续变化。

## 交互边界

- 单击滚动模式正文只保留现有阅读位置上报，不产生背景、描边、涟漪或“从这里朗读”按钮。
- 双击正文仍沿用现有 `chapterId + paragraphIndex` 精确起播。
- 播放中游标前进时，高亮从旧段落移动到新段落。
- 暂停、停止或播放状态变为非 `playing` 时，高亮立即消失。
- 分页模式原有选中与播放样式不在本次改动范围内。

## 数据流

`AudioHandler.playbackState` -> 阅读路由中的 `playing` 状态 -> `ReaderPage.playbackActive` -> 当前段落背景判断。

播放游标仍沿用现有 `PlaybackRuntime.cursorChanges`，不新增第二套段落位置状态。

## 测试

- Widget 测试先证明滚动模式下 `playing == true` 且游标匹配时当前段落使用 `paper.highlightWash`。
- 更新游标后，旧段落恢复中性，新段落显示高亮。
- `playing == false` 时，即使游标存在也不高亮。
- 单击正文仍不产生选择高亮或涟漪。
- 路由测试验证音频处理器的真实播放状态能够驱动阅读页高亮，而不是仅依赖游标存在。
