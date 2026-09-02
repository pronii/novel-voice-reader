# 声阅 (novel_voice_reader) 项目总结

> 生成时间：2026-08-18 · 基于 `main` 分支（`2330af5`）
> Flutter Android/iOS 小说语音朗读应用，支持 TXT/EPUB 导入、云端/MiMo TTS 朗读、按书音频缓存。

## 1. 产品定位

- 用户导入 **UTF-8 / UTF-16 / GB18030 的 TXT** 或 **非 DRM 的 EPUB**（单文件上限 100 MB）。
- 用 **OpenAI 兼容语音接口** 或 **Xiaomi MiMo** 朗读，每本书可独立配置语音与音频缓存策略。
- 核心价值：后台连续朗读 + 离线音频缓存（断网/锁屏也能听）。

## 2. 技术栈

| 领域 | 选型 |
|---|---|
| UI 框架 | Flutter 3.12（Dart 3.x），Material 3 |
| 状态管理 | flutter_riverpod（全局 Provider + 局部 ChangeNotifier） |
| 路由 | go_router（书架 / 阅读 / 播放 / 设置） |
| 本地数据库 | drift（SQLite，schema v3） |
| 网络 | dio（含超时与退避重试） |
| 文件解析 | file_picker + epubx + charset_converter |
| 音频播放 | just_audio + audio_service + audio_session（后台播放/媒体通知） |
| 安全存储 | flutter_secure_storage（API Key 存 Keystore/Keychain，不落 SQLite/日志） |
| 其他 | crypto（sha256 缓存键）、uuid、html、connectivity_plus、scrollable_positioned_list |

## 3. 架构（分层 + 功能垂直切分）

```
lib/
├── main.dart                 # 启动引导：DB / 安全存储 / 音频运行时初始化
├── app/                      # 路由、全局 Provider、主题、ProviderScope 注入
├── core/                     # 跨功能基础设施：DB、安全存储、网络、错误
└── features/                 # 按功能垂直切分，每个内部 domain/data/application/presentation 分层
    ├── speech/               # TTS 抽象、云/MiMo 客户端、音频引擎
    ├── downloads/            # 音频缓存任务调度、持久化、LRU 淘汰
    ├── library/              # 书架、导入、TXT/EPUB 解析
    ├── reader/               # 阅读页、章节滑动窗口、自动滚动、进度
    └── playback/             # 播放协调、后台音频、保活、睡眠定时器
```

- **依赖注入**：核心运行时对象（DB、playbackRuntime、audioCacheRuntime）经 `ProviderScope(overrides:)` 注入，便于测试替换。
- **跨层状态流**：`PlaybackCoordinator` 把播放流转播给 `NovelAudioHandler`（audio_service 媒体通知）。

## 4. 五大功能模块

### 4.1 书架与导入 (`library`)
- `book_import_repository`：100MB 上限，按扩展名选解析器，事务写入书/章/段。
- TXT：多编码解码 + 正则识别「第X章」式标题，前置文归为「前言」。
- EPUB：读 spine→HTML→语义块（h1/p/li）提正文；缺封面/图片不阻断，缺正文/DRM 则拒绝。

### 4.2 阅读器 (`reader`)
- 章节滑动窗口（最多 5 章），跨章导航；`PlaybackCursor(chapterId, paragraphIndex)` 定位。
- 自动滚动 1~100 级（10~150 px/s），手势暂停/恢复。
- 进度持久化与恢复，跨章剩余字数统计。

### 4.3 语音 / TTS (`speech`)
- `SpeechProvider` 接口族 + `SpeechEvent` 密封类（Started/Completed/Failed）。
- **兼容模式**：POST `{baseUrl}/v1/audio/speech`，Bearer 鉴权，3 次退避重试，`maxSegmentCharacters=1000`。
- **MiMo 模式**：POST `{baseUrl}/v1/chat/completions`，header `api-key`，返回 WAV 校验，默认模型 `mimo-v2.5-tts`、默认音色「冰糖」，`maxSegmentCharacters=360`。
- 文本按句切分为 `SpeechSegment`，缓存键 = 参数 JSON→sha256。

### 4.4 播放 (`playback`)
- `JustAudioPlaybackEngine` 用原生播放列表队列，音频完成由原生自动进阶（不回 Dart）。
- 后台：`NovelAudioHandler` 发布 NowPlaying/时间线；音频会话中断处理与保活（`SilentKeepAlivePlayer` 循环近静音 WAV 防 iOS 锁屏间隙挂起）。
- `PlaybackCoordinator`：按 segment 推进，看门狗（按字数估算+15s 宽限），5 分钟预取窗口。
- 睡眠定时器：15/30/45/60 分、或「本章播完」。

### 4.5 缓存 (`downloads`)
- 调度链：`AudioCacheRuntime` → `DownloadScheduler.reconcile`（算目标章窗 + 候选排序 + Wi-Fi 门控 + 预算估算）→ `DownloadPlanStore`（持久化）→ `AudioCacheTaskDispatcher`（优先级队列 + 网络门控）。
- 合成落盘：先写 `.partial` 再改名 + 格式校验；查找仅查盘。
- **LRU 淘汰**：按 `lastAccessedAt` 删旧音频；每书最近 3 个键受保护。
- 策略：仅 Wi-Fi 合成、每书 256MB~2GB 容量上限（默认 512MB）。

## 5. 数据模型（drift, 9 张表）

`Books` · `Chapters` · `Paragraphs` · `ReadingProgresses` · `VoiceProfiles` · `DownloadPolicies` · `AudioCacheEntries` · `DownloadJobs` · `TencentTtsMonthlyUsages`

- 级联删除：删书 → 删章 → 删段。
- 安全存储单独管理 `cloud_tts_api_key` / `mimo_tts_api_key`，写入失败回滚。

## 6. 路由表

| 路由 | 页面 |
|---|---|
| `/library` | 书架（导入、语音/缓存入口） |
| `/reader/:bookId` | 阅读页（可起播跳转播放） |
| `/player/:bookId` | 播放控制页 |
| `/settings/voice` | 语音设置（保存/测试连接） |
| `/settings/cache/:bookId` | 缓存策略页 |

## 7. 测试覆盖

- `test/` + `integration_test/` 约 50 个文件，按 `lib/` 结构镜像组织。
- 核心领域基本都有单测：播放协调器（1418 行）、后台音频 Handler（842）、缓存调度/计划、DB 迁移、TXT/EPUB 解析。
- 端到端：`integration_test/import_and_read_test.dart`（导入+朗读）。
- CI：`.github/workflows/ci.yml`。

## 8. 当前状态与备注

- 当前 `main` 最新提交聚焦播放保活与语音稳定性（背景循环不中断、移除系统 TTS 回退）。
- 本地 7 个分支全部对齐 origin；2 个 worktree 分支（`flutter-mvp`、`reader-playback-ux`）在各自 worktree 维护。
- 已知限制（README）：缓存任务依赖应用进程存活，被强杀后需重新打开才能续传；后台**播放**不受影响。
- 构建：Android APK 经 `tool/flutter.ps1 build apk`；iOS 需 macOS + Xcode。

## 9. 建议关注的演进方向

1. 真正的 OS 级后台下载任务（WorkManager / iOS BGTask）以支撑「被杀后自动续传」。
2. MiMo 与兼容模式的统一重试/退避与错误码归一化。
3. 缓存调度在弱网下的预算估算精度与抖动优化。
4. 阅读器与播放器共享 `PlaybackCursor` 的实时同步体验。
