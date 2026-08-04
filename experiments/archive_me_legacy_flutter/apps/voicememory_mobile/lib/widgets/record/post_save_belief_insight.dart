import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/archive_beliefs/archive_beliefs_presenter.dart';
import '../../models/journal_entry.dart';
import '../../product/consumer_copy_guard.dart';
import '../../product/belief_product_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_typography.dart';

/// Single post-save belief insight — one card, one next action.
class PostSaveBeliefInsight extends StatelessWidget {
  const PostSaveBeliefInsight({super.key, required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final last = entries.last;
    if (last.reflection.explainableConclusion?.provenance.generatedBy ==
        'model') {
      // Cloud-authored observations render only through the validated
      // ExplainableConclusionCard on the primary post-save surface.
      return const SizedBox.shrink();
    }
    final signals = ArchiveBeliefsPresenter.potentialSignalsFromEntry(last);
    final possible = signals.isNotEmpty
        ? signals.first
        : _beliefFromObservation(last);
    if (possible == null) return const SizedBox.shrink();

    final refs = _recurringReferenceCount(entries, possible);
    final confidence = refs >= 3 ? 'Medium' : 'Low';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: VoiceMemoryCards.standard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                BeliefProductCopy.postSavePossibleBelief,
                style: VoiceMemoryTypography.metadataStyle(
                  color: AppColors.accentPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '"$possible"',
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  fontSize: 20,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _row(BeliefProductCopy.postSaveConfidence, confidence),
              const SizedBox(height: 6),
              _row(
                BeliefProductCopy.postSaveBasedOn,
                '$refs recurring reference${refs == 1 ? '' : 's'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => context.go('/record'),
          child: const Text(BeliefProductCopy.postSaveRecordAnother),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: VoiceMemoryTypography.metadataStyle()),
        ),
        Expanded(child: Text(value, style: VoiceMemoryTypography.bodyStyle())),
      ],
    );
  }

  String? _beliefFromObservation(JournalEntry entry) {
    final obs = ConsumerCopyGuard.userFacingObservation(
      entry.reflection.concreteObservation,
    );
    if (obs == null) return null;
    if (obs.length >= 16) {
      return obs.length > 72 ? '${obs.substring(0, 69)}…' : obs;
    }
    return null;
  }

  int _recurringReferenceCount(List<JournalEntry> entries, String needle) {
    final n = needle.toLowerCase();
    var count = 0;
    for (final e in entries) {
      final blob =
          '${e.transcript} ${e.reflection.concreteObservation} '
                  '${e.reflection.repeatedSignal} '
                  '${e.reflection.recurringThemes.join(' ')}'
              .toLowerCase();
      if (blob.contains(n.split(' ').first)) count++;
    }
    return count.clamp(1, entries.length);
  }
}
