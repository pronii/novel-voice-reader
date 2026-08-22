import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/design/paper_tokens.dart';

/// A grouped settings block: an optional serif section title (with an optional
/// caption and trailing widget) sitting above a bordered, low-elevation "paper"
/// card that holds the group's controls.
///
/// Gives the settings screens a calm, sectioned hierarchy consistent with the
/// warm-paper theme instead of one long undivided column of fields.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.caption,
    this.trailing,
    required this.children,
  });

  final String? title;
  final String? caption;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(title!, style: theme.textTheme.titleMedium),
              ),
              ?trailing,
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// A sticky bottom action bar for a settings screen's primary action, kept out
/// of the scrolling body so it stays reachable regardless of content height.
///
/// Optionally shows a summary line above the button (e.g. "what will happen
/// when you apply").
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({super.key, this.summary, required this.action});

  final Widget? summary;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            Insets.md,
            Insets.page,
            Insets.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary != null) ...[
                summary!,
                const SizedBox(height: Insets.md),
              ],
              action,
            ],
          ),
        ),
      ),
    );
  }
}
