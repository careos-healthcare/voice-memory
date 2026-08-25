import 'package:archiveme_ui/models/next_moment_prompt.dart';
import 'package:flutter/material.dart';

/// Compact personalized prompt — what moment to capture next.
class NextMomentPromptCard extends StatelessWidget {
  const NextMomentPromptCard({
    required this.prompt,
    required this.onPrimary,
    super.key,
    this.onSecondary,
    this.compact = false,
  });

  final NextMomentPrompt prompt;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final bool compact;

  static const _sectionLabel = 'What to add next';
  static const _textPrimary = Color(0xFF172033);
  static const _textSecondary = Color(0xFF667085);
  static const _cardBackground = Color(0x99FFFFFF);
  static const _border = Color(0xFFE5E0D8);
  static const _shadow = Color(0x0D172033);
  static const _xs = 8.0;
  static const _sm = 16.0;

  @override
  Widget build(BuildContext context) {
    final helper = Theme.of(context).textTheme.bodySmall;
    final labelStyle = (helper ?? const TextStyle()).copyWith(
      color: _textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: _textPrimary,
      height: 1.35,
    );
    final bodyStyle = (helper ?? const TextStyle()).copyWith(
      color: _textSecondary,
      height: 1.4,
    );
    final padding = compact ? _sm : _sm + 4;

    return Container(
      key: const Key('next_moment_prompt_card'),
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: _shadow, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _sectionLabel,
            key: const Key('next_moment_prompt_section_label'),
            style: labelStyle,
          ),
          const SizedBox(height: _xs),
          Text(
            prompt.title,
            key: const Key('next_moment_prompt_title'),
            style: titleStyle,
          ),
          const SizedBox(height: _xs),
          Text(
            prompt.body,
            key: const Key('next_moment_prompt_body'),
            style: bodyStyle,
          ),
          if (!compact) ...[
            const SizedBox(height: _sm),
            OutlinedButton(
              key: const Key('next_moment_prompt_primary_cta'),
              onPressed: onPrimary,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(prompt.primaryCta),
            ),
            if (onSecondary != null && prompt.secondaryCta != null) ...[
              const SizedBox(height: _xs),
              TextButton(
                key: const Key('next_moment_prompt_secondary_cta'),
                onPressed: onSecondary,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(prompt.secondaryCta!),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
