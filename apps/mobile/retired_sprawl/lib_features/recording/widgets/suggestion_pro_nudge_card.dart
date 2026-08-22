import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Gentle post-save Pro nudge shown after a recording that started from a
/// daily suggestion. Dismissible, shows at most once per session, and never
/// appears for Pro users or before three saved entries.
class SuggestionProNudgeCard extends StatelessWidget {
  const SuggestionProNudgeCard({required this.onUnlock, required this.onDismiss, super.key,
  });

  final VoidCallback onUnlock;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('suggestion_pro_nudge_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep your daily archive prompts improving',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'ArchiveMe uses what you record to surface sharper things '
            'worth checking each day.',
            style: TextStyle(
              fontSize: 13,
              color: VoiceMemoryColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  // Compact override: the app-wide FilledButton theme is
                  // full-width, which cannot live inside this Row.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: onUnlock,
                  child: const Text(
                    'Unlock Pro',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onDismiss, child: const Text('Not now')),
            ],
          ),
        ],
      ),
    );
  }
}