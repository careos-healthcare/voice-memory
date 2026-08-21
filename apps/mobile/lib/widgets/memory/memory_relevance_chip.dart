import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_relevance_gate.dart';
import 'package:archiveme_mobile/features/memory/memory_relevance_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact relevance label above the archive memory cards.
///
/// Renders only for `possible` or `strong` relevance, and never claims
/// more than the evidence engines support:
/// - possible → cautious "may relate" wording only.
/// - strong → allowed only because an existing engine already has
///   supported evidence.
///
/// "Not related" lets the user decline the connection: that specific
/// connection is suppressed for the session (nothing is deleted, raw
/// entries are untouched, memory stays on for everything else).
class MemoryRelevanceChip extends StatelessWidget {
  const MemoryRelevanceChip({
    required this.assessment, super.key,
    this.marked = false,
    this.onMarkedNotRelated,
  });

  static const String possibleTitle = 'Possible connection';
  static const String possibleBody =
      'This may relate to something already in your archive.';
  static const String strongTitle = 'Strong connection';
  static const String strongBody =
      'This has enough evidence to compare with earlier entries.';
  static const String notRelatedLabel = 'Not related';
  static const String notRelatedConfirmation =
      'Thanks — ArchiveMe will treat this as separate.';

  final MemoryRelevanceAssessment assessment;

  /// True when the user marked this connection not related during this
  /// screen instance — shows the confirmation instead of the label.
  final bool marked;

  final VoidCallback? onMarkedNotRelated;

  @override
  Widget build(BuildContext context) {
    if (marked) {
      return Container(
        key: const Key('memory_relevance_not_related_confirmation'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
        child: Text(
          notRelatedConfirmation,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final relevance = assessment.relevance;
    if (relevance != MemoryRelevance.possible &&
        relevance != MemoryRelevance.strong) {
      return const SizedBox.shrink();
    }

    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryRelevanceSeen,
      relevance: relevance.id,
      entryCount: assessment.entryCount,
      oncePerSession: true,
    );

    final isStrong = relevance == MemoryRelevance.strong;
    return Container(
      key: const Key('memory_relevance_chip'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isStrong ? strongTitle : possibleTitle,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isStrong ? strongBody : possibleBody,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('memory_relevance_not_related'),
              onPressed: () {
                MemoryRelevanceGate.markNotRelated(
                  MemoryRelevanceGate.insightsConnectionId,
                );
                ActivationFunnelAnalytics.track(
                  ActivationFunnelAnalytics.memoryMarkedNotRelated,
                  relevance: relevance.id,
                  cardType: MemoryRelevanceGate.insightsConnectionId,
                  entryCount: assessment.entryCount,
                );
                onMarkedNotRelated?.call();
              },
              child: const Text(notRelatedLabel),
            ),
          ),
        ],
      ),
    );
  }
}