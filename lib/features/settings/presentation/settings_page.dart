import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/widgets/section_card.dart';

/// The unified settings screen: appearance, reading voice, updates — the
/// entries that used to pile up as icon-only app-bar buttons on the shelf.
final class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.onOpenVoiceSettings,
    this.onCheckUpdate,
    this.versionLabel,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback? onOpenVoiceSettings;
  final VoidCallback? onCheckUpdate;

  /// Human-readable running version (e.g. "当前版本 1.0.9 (10009)"), shown as
  /// the update row's subtitle. Null until package info resolves, or when the
  /// platform plugin is unavailable.
  final String? versionLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionCard(
            title: '外观',
            caption: '阅读界面的明暗与夜间模式',
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('跟随系统'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('浅色'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('深色'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) =>
                    onThemeModeChanged(selection.single),
              ),
              const SizedBox(height: 4),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '朗读',
            children: [
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('语音设置'),
                subtitle: const Text('语音服务、音色与语速'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenVoiceSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '通用',
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_alt_outlined),
                title: const Text('检查更新'),
                subtitle: Text(versionLabel ?? '查看是否有新版本'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onCheckUpdate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
