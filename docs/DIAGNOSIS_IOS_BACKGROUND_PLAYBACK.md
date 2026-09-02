# iOS 后台播放「缓存播完就断」诊断报告

> 数据来源：云端诊断 Collector（`feat/playback-telemetry` 分支上报）
> 服务器：`http://45.136.28.241/nvr/collect` → docker `nvr-collector` → `/opt/nvr-collector/data/telemetry.jsonl`
> 分析文件：`telemetry.jsonl`（69 条批次，9 个会话；其中 7 个 iOS 会话，全部 `Version 27.0 (Build 24A5355q)`）

## 结论（一句话）

**锁屏后台播放时，缓存播完、需要现合成下一段云端语音的那一刻，代码去 Keychain 读 API Key，iOS 返回 `-25308 User interaction is not allowed`（设备锁屏、Keychain 不可访问），云端语音「播放准备失败」，播放直接中断。**

这与「音频会话被 iOS 挂起」无关——日志明确显示保活音 (`keepalive.start`) 一直在 `playing:true` 正常运行，断点是**合成环节读密钥失败**。

## 真机证据（三个失败会话）

| 会话 launchId | 时间 | 播放区间 (mono) | 断点事件 |
|---|---|---|---|
| `abc6ff47…` | 08-18 02:30 | playing t=8.87s → **78.26s 失败** | `playback.failure`: `云端语音播放准备失败 (PlatformException Unexpected security result code: Code: -25308, Message: User interaction is not allowed.)` |
| `92a1a6ee…` | 08-17 18:18 | playing t=5.59s → **110.82s 失败** | `playback.failure`: `云端语音播放准备失败 (PlatformException)` + `keepalive.stop` |
| `3e71e32c…` | 08-17 12:26 | playing t=8.79s → **74.99s 失败** | `playback.failure`: `云端语音播放准备失败` + `keepalive.stop` |

三个会话的共同特征：
- 都先 `keepalive.start`（`shouldRender:true, playing:true`）→ 证明静音保活音正常、iOS 没挂起进程；
- 播放约 1–2 分钟（即首批已缓存段落）后，第一次遇到「缓存边界需要现合成」→ 立即 `playback.activity kind:failed`；
- 失败信息都指向**云端语音播放准备**失败，而非音频会话/网络超时。

对比另外两个有 keepalive 但没有 failure 的会话（`f900723c`、`0bff1c50`、`4da1747e`）：它们只走到 `keepalive.stop`（`playing:false`），但**没有 `playback.failure`** —— 说明它们要么没遇到锁屏下的缓存边界合成，要么在前台，不构成断流。

## 代码链路（根因定位）

1. `lib/features/speech/data/cached_audio_speech_provider.dart`
   - `prepare()` → `_obtain(segment, profile)` → `cache.obtain(...)`（行 229/304/440）
   - 失败在 `catch` 里被包装成 `AppFailure('云端语音播放准备失败 (PlatformException ...)')`（行 257-263）——**与日志完全一致**。
2. `cache.obtain` 走云端合成，需要 API Key：
   - `lib/features/speech/data/cloud_tts_client.dart:32` → `final apiKey = await credentials.readApiKey();`
   - `lib/features/speech/data/mimo_tts_client.dart:37` → `await credentials.readMiMoApiKey()`
   - **每次合成都重新从 Keychain 读 Key，无任何内存缓存。**
3. `lib/core/storage/secure_credentials.dart`
   - `readApiKey()` 直接 `FlutterSecureStorage.read()`，Keychain 默认可访问性要求设备已解锁。
   - 锁屏后台读取 → `errSecInteractionNotAllowed = -25308`。

## 修复方案（按推荐顺序）

**方案 A（首选，治本，一行配置）**
把 `FlutterSecureStorage` 的 iOS Keychain 可访问性改为「首次解锁后可读（设备内）」：
`IOSOptions(accessibility: IOSAccessibility.first_unlock_this_device_only)`
- 改动点：`lib/main.dart:39`、`lib/app/router.dart:363`、`lib/app/router.dart:595`（三处构造 `FlutterSecureStorage` 的地方）。
- 代价：Key 在锁屏后也可读，安全性略降（对本地缓存型 TTS Key 可接受，行业惯例）。

**方案 B（加固，去 Keychain 依赖）**
在 `SecureCredentials` 内加内存缓存：首次读取后存到 Dart 字段，合成路径优先用内存副本，写 Key 时同步刷新；后台合成不再碰 Keychain。

**方案 C（防御性）**
`prepare()` 的 `catch` 中识别 `-25308`，用内存缓存 Key 重试一次；仍失败则上报「请在解锁状态下开始播放」而非静默断流。

**建议 A + B 一起做**：A 直接解决 -25308；B 让后台合成彻底不依赖 Keychain，最稳。

## 验证路径
改完后真机锁屏播一本「缓存边界在中段」的书，观察 `telemetry.jsonl` 是否还有 `playback.failure` 含 `-25308`；或本地用 `flutter test` 覆盖 `SecureCredentials` 内存缓存与 `cloud_tts_client` 后台读 Key 分支。
