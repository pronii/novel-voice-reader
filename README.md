# 声阅

声阅是一个 Flutter Android/iOS 小说朗读应用。用户可导入 UTF-8、UTF-16、GB18030 TXT 或非 DRM EPUB，使用系统 TTS、OpenAI 兼容语音接口或 Xiaomi MiMo 朗读，并为每本书单独设置后续音频缓存。

EPUB 解析只读取书籍 spine 中的章节正文。缺失封面、图片、字体等非正文资源不会阻止导入；缺少章节正文、受 DRM 保护或没有可阅读内容的 EPUB 仍会被拒绝。

单个导入文件上限为 100 MB。文件选择器只保留文件引用，确定导入后才读取内容，避免在选择阶段复制整本书到内存。

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

## 语音服务

“系统”模式直接使用设备 TTS，不需要 API Key，也不会生成可复用的音频缓存。

在“语音设置”选择“兼容”，填写 Base URL、模型、音色与 API Key。服务需兼容：

```text
POST {baseUrl}/v1/audio/speech
Authorization: Bearer {apiKey}
Content-Type: application/json
```

请求字段为 `model`、`voice`、`input`、`speed` 和 `response_format`。Base URL 可以填写服务根地址，也可以直接以 `/v1` 结尾。

“MiMo”模式使用 Xiaomi MiMo 语音服务，支持预置中英文音色和自然语言朗读风格。兼容接口与 MiMo 都需要用户自己的 API Key；密钥只写入 Android Keystore/iOS Keychain 支持的安全存储，不进入 SQLite、缓存任务或日志。留空保存会保留已经存储的密钥。

## 缓存策略

在书架中点击每本书右侧的缓存按钮，可输入从 0 到剩余章节数的任意整数，也可选择缓存全部未读章节。`0` 表示缓存当前章节。缓存支持仅 Wi-Fi 合成和每本书 256 MB 至 2 GB 的容量上限，超过上限时按最近最少使用顺序清理旧音频。

缓存任务与播放共用同一套文件和索引，不会重复合成同一段音频。任务在应用进程存活时执行，网络恢复后会自动续传；重新打开应用时会恢复所有已保存的缓存计划。当前版本没有注册操作系统级后台下载任务，应用被强制结束后仍需重新打开才能继续补充缓存。后台音频播放不受此限制。
