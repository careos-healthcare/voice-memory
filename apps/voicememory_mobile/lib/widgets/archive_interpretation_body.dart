import 'package:flutter/material.dart';

import '../design/user_facing_date.dart';
import '../features/archive_explanation_v2/archive_explanation_v2_analytics.dart';
import '../features/archive_explanation_v2/archive_interpretation_store.dart';
import '../services/app_services.dart';
import '../features/archive_explanation_v2/archive_interpretation_models.dart';
import '../features/archive_explanations/explanation_models.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Archive Explanation V2 — evidence-grounded interpretation journey.
class ArchiveInterpretationBody extends StatefulWidget {
  const ArchiveInterpretationBody({
    super.key,
    required this.interpretation,
    required this.accent,
    required this.onOpenEntry,
    required this.onOpenTheme,
    required this.onOpenContradiction,
    required this.onOpenBlindSpot,
    required this.onRecordToExplore,
  });

  final ArchiveInterpretation interpretation;
  final Color accent;
  final void Function(String entryId) onOpenEntry;
  final void Function(String themeKey) onOpenTheme;
  final void Function(String contradictionId) onOpenContradiction;
  final void Function(String blindSpotId) onOpenBlindSpot;
  final VoidCallback onRecordToExplore;

  @override
  State<ArchiveInterpretationBody> createState() =>
      _ArchiveInterpretationBodyState();
}

class _ArchiveInterpretationBodyState extends State<ArchiveInterpretationBody> {
  var _deeperExpanded = false;
  var _showAllSupporting = false;
  var _showAllContradicting = false;
  var _loggedFollowupView = false;
  var _loggedCompleted = false;

  ArchiveInterpretation get i => widget.interpretation;

  void _openDeeper() {
    if (!_deeperExpanded) {
      ArchiveExplanationV2Analytics.goDeeperOpened(
        insightId: i.insightId,
        kind: i.kind.name,
      );
      setState(() => _deeperExpanded = true);
      _maybeLogFollowupViewed();
    }
  }

  void _maybeLogFollowupViewed() {
    if (_loggedFollowupView) return;
    _loggedFollowupView = true;
    ArchiveInterpretationStore(AppServices.instance.prefs)
        .markFollowupQuestionSeen(i.followUpQuestion);
    ArchiveExplanationV2Analytics.followupQuestionViewed(
      insightId: i.insightId,
      kind: i.kind.name,
    );
    if (!_loggedCompleted) {
      _loggedCompleted = true;
      ArchiveExplanationV2Analytics.interpretationCompleted(
        insightId: i.insightId,
        kind: i.kind.name,
      );
    }
  }

  static String _trendLabel(BeliefTimelineTrend t) => switch (t) {
        BeliefTimelineTrend.strengthening => 'May be strengthening',
        BeliefTimelineTrend.weakening => 'May be weakening',
        BeliefTimelineTrend.stable => 'May appear steady',
        BeliefTimelineTrend.unknown => 'Still forming',
      };

  @override
  Widget build(BuildContext context) {
    final supporting = _showAllSupporting
        ? i.supportingEvidence
        : i.supportingEvidence.take(4).toList();
    final contradicting = _showAllContradicting
        ? i.contradictingEvidence
        : i.contradictingEvidence.take(3).toList();
    final timeline = i.timeline;
    final timelinePoints = timeline.points.length <= 4
        ? timeline.points
        : timeline.points.sublist(timeline.points.length - 4);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        Text(
          'ARCHIVE EXPLANATION',
          style: VoiceMemoryTypography.sectionLabelStyle(accent: widget.accent),
        ),
        const SizedBox(height: 12),
        if (i.beliefStatement != null) ...[
          Text(
            '“${i.beliefStatement}”',
            style: VoiceMemoryTypography.cardTitleStyle(),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Text(i.title, style: VoiceMemoryTypography.cardTitleStyle()),
          const SizedBox(height: 12),
        ],
        _SectionHeader('WHY?', accent: widget.accent),
        const SizedBox(height: 8),
        Text(
          i.whyText,
          style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
        ),
        const SizedBox(height: 24),
        _SectionHeader('EVIDENCE', accent: widget.accent),
        const SizedBox(height: 8),
        if (supporting.isEmpty)
          Text(
            'No linked entries yet.',
            style: VoiceMemoryTypography.bodyStyle(
              color: VoiceMemoryColors.textSecondary,
            ),
          )
        else ...[
          ...supporting.map(
            (ref) => _EvidenceTile(ref: ref, onTap: widget.onOpenEntry),
          ),
          if (!_showAllSupporting && i.supportingEvidence.length > supporting.length)
            TextButton(
              onPressed: () => setState(() => _showAllSupporting = true),
              child: const Text('Show all supporting entries'),
            ),
        ],
        const SizedBox(height: 24),
        _SectionHeader('TIMELINE', accent: widget.accent),
        const SizedBox(height: 8),
        if (!i.hasTimeline)
          Text(
            'No timeline points for this insight yet.',
            style: VoiceMemoryTypography.bodyStyle(
              color: VoiceMemoryColors.textSecondary,
            ),
          )
        else ...[
          if (timeline.firstSeen != null)
            Text(
              'First seen: ${formatUserFacingMonthYear(timeline.firstSeen!)}',
              style: VoiceMemoryTypography.bodyStyle(),
            ),
          Text(
            'Peak: ${timeline.peakLabel} (${timeline.peakPercent}% signal)',
            style: VoiceMemoryTypography.bodyStyle(),
          ),
          Text(
            'Current: ${timeline.currentLabel} (${timeline.currentPercent}% signal)',
            style: VoiceMemoryTypography.bodyStyle(),
          ),
          Text(
            'Trend: ${_trendLabel(timeline.trend)}',
            style: VoiceMemoryTypography.metadataStyle(),
          ),
          const SizedBox(height: 8),
          ...timelinePoints.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${p.label} ${p.year}: ${p.strengthPercent}% signal',
                style: VoiceMemoryTypography.bodyStyle(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _SectionHeader('CROSS REFERENCES', accent: widget.accent),
        const SizedBox(height: 8),
        if (!i.hasCrossReferences)
          Text(
            'No related themes or tensions linked yet.',
            style: VoiceMemoryTypography.bodyStyle(
              color: VoiceMemoryColors.textSecondary,
            ),
          )
        else ...[
          if (i.relatedThemes.isNotEmpty) ...[
            Text('Themes', style: VoiceMemoryTypography.metadataStyle()),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: i.relatedThemes
                  .take(6)
                  .map(
                    (t) => ActionChip(
                      label: Text(t.name),
                      onPressed: () => widget.onOpenTheme(t.themeKey),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (i.relatedBlindSpots.isNotEmpty) ...[
            Text('Contradictions', style: VoiceMemoryTypography.metadataStyle()),
            ...i.relatedBlindSpots.take(3).map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.headline),
                    onTap: () => widget.onOpenBlindSpot(s.id),
                  ),
                ),
          ],
          if (i.relatedContradictions.isNotEmpty) ...[
            Text('Tensions', style: VoiceMemoryTypography.metadataStyle()),
            ...i.relatedContradictions.take(3).map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.summary),
                    onTap: () => widget.onOpenContradiction(c.id),
                  ),
                ),
          ],
        ],
        const SizedBox(height: 24),
        if (i.hasDeeperContent) ...[
          OutlinedButton(
            onPressed: _openDeeper,
            style: OutlinedButton.styleFrom(
              foregroundColor: VoiceMemoryColors.primaryIndigo,
              side: const BorderSide(color: VoiceMemoryColors.primaryIndigo),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(_deeperExpanded ? 'GO DEEPER (OPEN)' : 'GO DEEPER'),
          ),
        ],
        if (_deeperExpanded) ...[
          const SizedBox(height: 20),
          _DeeperPanel(
            interpretation: i,
            accent: widget.accent,
            contradicting: contradicting,
            showAllContradicting: _showAllContradicting,
            totalContradicting: i.contradictingEvidence.length,
            onShowAllContradicting: () =>
                setState(() => _showAllContradicting = true),
            onOpenEntry: widget.onOpenEntry,
            onRecordToExplore: () {
              ArchiveExplanationV2Analytics.followupQuestionUsed(
                insightId: i.insightId,
                kind: i.kind.name,
              );
              widget.onRecordToExplore();
            },
          ),
        ],
      ],
    );
  }
}

class _DeeperPanel extends StatelessWidget {
  const _DeeperPanel({
    required this.interpretation,
    required this.accent,
    required this.contradicting,
    required this.showAllContradicting,
    required this.totalContradicting,
    required this.onShowAllContradicting,
    required this.onOpenEntry,
    required this.onRecordToExplore,
  });

  final ArchiveInterpretation interpretation;
  final Color accent;
  final List<EvidenceReference> contradicting;
  final bool showAllContradicting;
  final int totalContradicting;
  final VoidCallback onShowAllContradicting;
  final void Function(String entryId) onOpenEntry;
  final VoidCallback onRecordToExplore;

  @override
  Widget build(BuildContext context) {
    final i = interpretation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('WHAT THIS MIGHT MEAN', accent: accent),
          const SizedBox(height: 8),
          Text(
            i.whatThisMightMean,
            style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
          ),
          const SizedBox(height: 20),
          _SectionHeader('WHAT SUPPORTS THIS', accent: accent),
          const SizedBox(height: 8),
          if (i.supportsSummary.bullets.isEmpty)
            const Text('No supporting summary yet.')
          else
            ...i.supportsSummary.bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $b', style: VoiceMemoryTypography.bodyStyle()),
              ),
            ),
          const SizedBox(height: 8),
          ...i.supportsSummary.entries
              .take(3)
              .map((ref) => _EvidenceTile(ref: ref, onTap: onOpenEntry)),
          const SizedBox(height: 20),
          _SectionHeader(
            'WHAT CONTRADICTS THIS',
            accent: VoiceMemoryColors.contradictionRose,
          ),
          const SizedBox(height: 8),
          if (i.contradictsSummary.bullets.isEmpty && contradicting.isEmpty)
            Text(
              'No counter-evidence surfaced for this insight.',
              style: VoiceMemoryTypography.bodyStyle(
                color: VoiceMemoryColors.textSecondary,
              ),
            )
          else ...[
            ...i.contradictsSummary.bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $b', style: VoiceMemoryTypography.bodyStyle()),
              ),
            ),
            const SizedBox(height: 8),
            ...contradicting.map(
              (ref) => _EvidenceTile(ref: ref, onTap: onOpenEntry),
            ),
            if (!showAllContradicting && totalContradicting > contradicting.length)
              TextButton(
                onPressed: onShowAllContradicting,
                child: const Text('Show all contradicting entries'),
              ),
          ],
          const SizedBox(height: 20),
          _SectionHeader("WHAT WOULD CHANGE THE ARCHIVE'S MIND", accent: accent),
          const SizedBox(height: 8),
          if (i.mindChange.strongerIf.isNotEmpty) ...[
            Text('Stronger if:', style: VoiceMemoryTypography.metadataStyle()),
            ...i.mindChange.strongerIf.map(
              (s) => Text('• $s', style: VoiceMemoryTypography.bodyStyle()),
            ),
          ],
          if (i.mindChange.weakerIf.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Weaker if:', style: VoiceMemoryTypography.metadataStyle()),
            ...i.mindChange.weakerIf.map(
              (s) => Text('• $s', style: VoiceMemoryTypography.bodyStyle()),
            ),
          ],
          const SizedBox(height: 20),
          _SectionHeader('ONE QUESTION TO EXPLORE NEXT', accent: accent),
          const SizedBox(height: 8),
          Text(
            i.followUpQuestion,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRecordToExplore,
            style: FilledButton.styleFrom(
              backgroundColor: VoiceMemoryColors.primaryIndigo,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Record to explore'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: VoiceMemoryTypography.sectionLabelStyle(accent: accent),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.ref, required this.onTap});

  final EvidenceReference ref;
  final void Function(String entryId) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onTap(ref.entryId),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatUserFacingDate(ref.recordedAt),
                style: VoiceMemoryTypography.metadataStyle(),
              ),
              const SizedBox(height: 4),
              Text(
                '“${ref.excerpt}”',
                style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
