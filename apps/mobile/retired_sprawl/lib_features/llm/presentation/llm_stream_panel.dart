import 'package:archiveme_mobile/features/llm/domain/llm_feed_card_state.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// StreamBuilder panel that renders incremental LLM token output.
class LlmStreamPanel extends StatelessWidget {
  const LlmStreamPanel({
    required this.tokenStream,
    super.key,
    this.placeholder = 'Analyzing reflection…',
    this.idle,
  });

  final Stream<LlmStreamToken> tokenStream;
  final String placeholder;
  final Widget? idle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<LlmStreamToken>(
      key: const Key('llm_stream_panel'),
      stream: tokenStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Analysis failed.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.error,
            ),
          );
        }

        if (!snapshot.hasData) {
          return idle ??
              Text(
                placeholder,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              );
        }

        final event = snapshot.data!;
        if (event.isFinal && event.accumulatedText.trim().isEmpty) {
          return Text(
            placeholder,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          );
        }

        final text = event.accumulatedText.trim().isEmpty
            ? event.token
            : event.accumulatedText;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: Text(
            text.isEmpty ? placeholder : text,
            key: ValueKey<String>(text),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        );
      },
    );
  }
}
