# MiMo V2.5 TTS 接入设计

## 目标

在现有系统、兼容、Azure、智谱和腾讯云语音 Provider 之外增加 Xiaomi MiMo，并让用户选择官方预置音色、填写自然语言朗读风格、验证 API Key 后保存。播放器继续负责精确倍速，MiMo 负责语义层面的语速、情绪和语气。

## 范围

- 使用 `https://api.xiaomimimo.com/v1/chat/completions` 和 `mimo-v2.5-tts`。
- 支持冰糖、茉莉、苏打、白桦、Mia、Chloe、Milo、Dean 八个官方预置音色。
- 支持可选朗读风格文本，作为 `user` 消息；正文作为 `assistant` 消息。
- 请求 WAV 音频，解析响应中的 Base64 `choices[0].message.audio.data`。
- 提供 API Key 连通性测试、鉴权失败、限流、超时和无效音频提示。
- MiMo Key 只存入 `flutter_secure_storage`。
- 保持播放器的 0.5x 至 2.0x 精确倍速机制。

## 非目标

- 本期不做 VoiceDesign、VoiceClone、参考音频上传或服务端代理。
- 不提供免费额度查询；官方当前只有限时免费说明，没有稳定的余额查询契约。
- 不自动分析整章并插入情绪标签，避免改写用户导入的正文。

## 架构与数据流

`VoiceSettingsPage` 生成 `VoiceProfile.mimo` 和标准 `SpeechCredentialsInput`。路由层先用输入的 Key 调用 `MiMoTtsClient.testConnection`，保存时写入独立安全凭据并更新当前语音配置。`SpeechProviderFactory` 将 MiMo Profile 映射为带缓存和可调播放速度的云端 Provider。

合成时，客户端读取安全存储中的 MiMo Key，构造 OpenAI Chat Completions 兼容请求。风格为空时使用稳定的默认小说旁白指导；服务返回 Base64 WAV 后严格解码并验证 RIFF/WAVE 文件头，再交给现有音频缓存和播放器。

## 错误与隐私

401/403 映射为认证失败，429 映射为请求过于频繁，5xx 和网络瞬态错误使用有上限的退避重试。界面只显示清洗后的 `AppFailure`，不显示响应体、Key 或底层异常。API Key 不进入 Profile、缓存键、普通偏好或日志。

## 测试

- `VoiceProfile`：默认值、音色白名单、风格规范化和分段上限。
- `MiMoTtsClient`：请求结构、两种鉴权、Base64 WAV 解析、空/损坏响应、鉴权、限流和重试。
- 安全存储：MiMo Key 独立存储和规范化。
- Factory：MiMo 映射到缓存 Provider。
- 设置页：窄屏选择音色、风格、Key、连接测试和保存。
- 路由映射：MiMo 的测试连接与安全保存。

