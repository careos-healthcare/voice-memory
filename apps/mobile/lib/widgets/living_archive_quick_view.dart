import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_evolution/archive_evolution_copy.dart';
import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_navigation.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_analytics.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_copy.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_evidence_panel.dart';
import 'package:archiveme_mobile/widgets/archive_evolution_card.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Archive home — one evolution hero, anticipation, optional View More.
class LivingArchiveQuickView extends StatefulWidget {
  const LivingArchiveQuickView({
    required this.view, required this.entries, super.key,
    this.onViewAllDiscoveries,
    this.onEvolutionDismissed,
  });

  final LivingArchiveView view;
  final List<JournalEntry> entries;
  final VoidCallback? onViewAllDiscoveries;
  final VoidCallback? onEvolutionDismissed;

  @override
  State<LivingArchiveQuickView> createState() => _LivingArchiveQuickViewState();
}

class _LivingArchiveQuickViewState extends State<LivingArchiveQuickView> {
  var _viewMoreExpanded = false;

  bool get _showViewMore => widget.view.hasCollapsedContent;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final evolution = view.evolution;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ArchiveEvolutionCopy.archiveQuestion,
          style: VoiceMemoryTypography.sectionLabelStyle(
            
          ),
        ),
        const SizedBox(height: ArchiveMobileSpacing.md),
        if (evolution != null)
          ArchiveEvolutionCard(
            evolution: evolution,
            entries: widget.entries,
            onDismissed: widget.onEvolutionDismissed,
          )
        else
          _ArchiveStillLearningCard(entries: widget.entries),
        const SizedBox(height: ArchiveMobileSpacing.md),
        ArchiveEvolutionAnticipationRow(
          discoveryStreakDays: view.discoveryStreak.consecutiveDays,
          lastArchiveUpdateAt: view.lastArchiveUpdateAt,
        ),
        if (_showViewMore) ...[
          const SizedBox(height: ArchiveMobileSpacing.md),
          TextButton(
            onPressed: () {
              setState(() => _viewMoreExpanded = !_viewMoreExpanded);
              if (_viewMoreExpanded) {
                unawaited(LivingArchiveAnalytics.viewAllDiscoveriesTapped());
              }
            },
            child: Text(
              _viewMoreExpanded ? 'Show less' : LivingArchiveCopy.viewMoreLabel,
            ),
          ),
          if (_viewMoreExpanded && widget.onViewAllDiscoveries != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: widget.onViewAllDiscoveries,
              child: const Text('See full archive'),
            ),
          ],
        ],
        if (_viewMoreExpanded) ...[
          if (view.mostImportant != null) ...[
            const SizedBox(height: ArchiveMobileSpacing.md),
            _SecondaryInsightCard(
              insight: view.mostImportant!,
              entries: widget.entries,
            ),
          ],
          if (view.whatChangedToday != null &&
              view.whatChangedToday!.hasContent) ...[
            const SizedBox(height: ArchiveMobileSpacing.md),
            _WhatChangedTodayCard(
              changed: view.whatChangedToday!,
              entries: widget.entries,
            ),
          ],
        ],
      ],
    );
  }
}

class _ArchiveStillLearningCard extends StatelessWidget {
  const _ArchiveStillLearningCard({required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final hasEvidence = archiveHasMinimumEvidence(entries);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LivingArchiveCopy.stillLearning,
            style: VoiceMemoryTypography.cardTitleStyle(),
          ),
          if (hasEvidence) ...[
            const SizedBox(height: 8),
            Text(
              LivingArchiveCopy.oneMoreRecording,
              style: VoiceMemoryTypography.bodyStyle(
                color: VoiceMemoryColors.textSecondary,
              ).copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecondaryInsightCard extends StatefulWidget {
  const _SecondaryInsightCard({required this.insight, required this.entries});

  final MostImportantInsight insight;
  final List<JournalEntry> entries;

  @override
  State<_SecondaryInsightCard> createState() => _SecondaryInsightCardState();
}

class _SecondaryInsightCardState extends State<_SecondaryInsightCard> {
  var _evidenceOpen = false;

  @override
  Widget build(BuildContext context) {
    final i = widget.insight;
    final byId = {for (final e in widget.entries) e.id: e};
    final evidenceEntries = [
      for (final id in i.evidenceIds)
        if (byId[id] != null) byId[id]!,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Also in your archive',
            style: VoiceMemoryTypography.metadataStyle(),
          ),
          const SizedBox(height: 8),
          Text(i.headline, style: VoiceMemoryTypography.bodyStyle()),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              openArchiveExplanation(
                context,
                ref: i.insightRef,
                askPrompt: i.askPrompt,
                askCitedEntryIds: i.evidenceIds,
              );
            },
            child: const Text('Why?'),
          ),
          if (evidenceEntries.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _evidenceOpen = !_evidenceOpen),
              child: Text(_evidenceOpen ? 'Hide evidence' : 'Show evidence'),
            ),
          if (_evidenceOpen)
            ArchiveEvidencePanel(
              entries: evidenceEntries,
              analyticsContext: 'secondary_insight',
            ),
        ],
      ),
    );
  }
}

class _WhatChangedTodayCard extends StatelessWidget {
  const _WhatChangedTodayCard({required this.changed, required this.entries});

  final WhatChangedToday changed;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What changed today?',
            style: VoiceMemoryTypography.sectionLabelStyle(
              
            ),
          ),
          const SizedBox(height: 8),
          for (final line in changed.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line.displayText ??
                    '${line.label}: ${line.before} → ${line.after}',
                style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.4),
              ),
            ),
          TextButton(
            onPressed: () {
              openArchiveExplanation(
                context,
                ref: changed.insightRef,
                askCitedEntryIds: changed.evidenceIds,
              );
            },
            child: const Text('Why?'),
          ),
        ],
      ),
    );
  }
}