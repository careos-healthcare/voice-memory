import 'package:archiveme_mobile/features/capture/services/entry_save_pipeline.dart';
import 'package:flutter/material.dart';

/// Live bubbles for a Reflect with me conversation.
///
/// The person's words stay in the normal text style. App questions are
/// italic, on a tinted background, with a spark icon.
class VoiceChatView extends StatelessWidget {
  const VoiceChatView({
    required this.lines,
    super.key,
  });

  final List<VoiceChatLine> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          _bubble(context, lines[index], index),
        ],
      ],
    );
  }

  Widget _bubble(BuildContext context, VoiceChatLine line, int index) {
    if (line.isUser) {
      return Semantics(
        label: 'Your words',
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            line.text,
            key: Key('voice_chat_user_$index'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'App question',
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          key: Key('voice_chat_app_$index'),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thoughtprint asked',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSecondaryContainer.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      Text(
                        line.text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: scheme.onSecondaryContainer.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
