# 声阅

声阅是一个 Flutter Android/iOS 小说朗读应用。用户可导入 UTF-8、UTF-16、GB18030 TXT 或非 DRM EPUB，使用系统 TTS、OpenAI 兼容接口、Azure AI Speech 或智谱 GLM-TTS 朗读，并按自定义章节数缓存后续音频。

EPUB 解析只读取书籍 spine 中的章节正文。缺失封面、图片、字体等非正文资源不会阻止导入；缺少章节正文、受 DRM 保护或没有可阅读内容的 EPUB 仍会被拒绝。

## 本地开发

Windows：

```powershell
pwsh -File tool/bootstrap_flutter.ps1
pwsh -File tool/bootstrap_android.ps1
pwsh -File tool/flutter.ps1 pub get
pwsh -File tool/flutter.ps1 test
pwsh -File tool/flutter.ps1 analyze
pwsh -File tool/flutter.ps1 build apk --debug --no-pub
```

生成的 APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`。iOS 构建需要 macOS 与 Xcode：

```bash
flutter pub get
flutter build ios --debug --no-codesign
```

## 云端语音

在“语音设置”选择“兼容”，填写 Base URL、模型、音色与 API Key。服务需兼容：

```text
POST {baseUrl}/v1/audio/speech
Authorization: Bearer {apiKey}
Content-Type: application/json
```

请求字段为 `model`、`voice`、`input`、`speed` 和 `response_format`。API Key 只写入 Android Keystore/iOS Keychain 支持的安全存储，不进入 SQLite、下载任务或日志。

选择“Azure”可填写 Region、神经网络音色与 Subscription Key，应用使用 Azure AI Speech 官方 REST Endpoint 和 SSML 合成 MP3。

选择“智谱”时，应用固定使用官方接口 `https://open.bigmodel.cn/api/paas/v4/audio/speech`、模型 `glm-tts` 和 WAV 输出。支持以下系统音色：

- 彤彤 `tongtong`
- 锤锤 `chuichui`
- 小陈 `xiaochen`
- `jam`
- `kazi`
- `douji`
- `luodo`

智谱模式需要用户自己的 API Key。可用额度和价格以智谱开放平台当前规则为准，应用不承诺永久免费。

## 缓存策略

用户可输入从 0 到剩余章节数的任意整数，也可选择缓存全部未读章节。缓存支持仅 Wi-Fi 下载和 256 MB 至 2 GB 容量上限。iOS 被用户强制结束后不会保证自动补充任务，这是系统后台策略限制。
