import 'package:flutter/material.dart';

import '../features/archive_explanations/archive_explanation_analytics.dart';
import '../features/archive_explanations/archive_explanation_engine.dart';
import '../features/archive_explanations/archive_explanation_navigation.dart';
import '../features/archive_explanations/explanation_models.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../models/journal_entry.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Discover feed: top surprise / challenge / emerging patterns.
class YourArchiveNoticedSection extends StatelessWidget {
  const YourArchiveNoticedSection({
    super.key,
    required this.entries,
    this.state,
  });

  final List<JournalEntry> entries;
  final ArchiveStateObjectV3? state;

  @override
  Widget build(BuildContext context) {
    final items = const ArchiveExplanationEngine().buildNoticedFeed(
      entries: entries,
      state: state,
    );
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR ARCHIVE NOTICED',
          style: VoiceMemoryTypography.sectionLabelStyle(
            accent: VoiceMemoryColors.discoveryGold,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _NoticedCard(item: item)),
      ],
    );
  }
}

class _NoticedCard extends StatelessWidget {
  const _NoticedCard({required this.item});

  final ArchiveNoticedItem item;

  @override
  Widget build(BuildContext context) {
    final borderColor = item.isGold
        ? VoiceMemoryColors.discoveryGoldBorder
        : VoiceMemoryColors.border;
    final bg = item.isGold
        ? VoiceMemoryColors.discoveryGoldBackground
        : VoiceMemoryColors.surface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            if (item.isChallenge) {
              ArchiveExplanationAnalytics.challengeViewed(refId: item.ref.id);
            } else if (item.ref.kind == ArchiveInsightKind.surprise) {
              ArchiveExplanationAnalytics.surpriseViewed(refId: item.ref.id);
            }
            openArchiveExplanation(context, ref: item.ref);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.headline,
                  style: VoiceMemoryTypography.metadataStyle(
                    color: item.isGold
                        ? VoiceMemoryColors.discoveryGold
                        : VoiceMemoryColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.preview,
                  style: VoiceMemoryTypography.bodyStyle().copyWith(
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.isChallenge ? 'Tap to see why' : 'Learn more',
                  style: VoiceMemoryTypography.secondaryStyle(
                    color: VoiceMemoryColors.primaryIndigo,
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
