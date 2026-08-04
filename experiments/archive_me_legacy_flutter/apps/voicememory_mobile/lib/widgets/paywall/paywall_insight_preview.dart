import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_analyst/archive_analyst_engine.dart';
import '../../features/archive_analyst/archive_analyst_gate.dart';
import '../../features/archive_analyst/archive_analyst_models.dart';
import '../../features/archive_memory/archive_evolution_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Interactive, fictional Pro-output preview shown before purchase controls.
class PaywallInsightPreview extends StatefulWidget {
  const PaywallInsightPreview({
    super.key,
    this.analystEngine = const ArchiveAnalystEngine(),
    this.report,
    this.timeline,
  });

  final ArchiveAnalystEngine analystEngine;
  final ArchiveAnalystReport? report;
  final ArchiveEvolutionTimeline? timeline;

  static final sampleReport = ArchiveAnalystReport(
    level: ArchiveAnalystLevel.level1,
    eligibleReflectionCount: 58,
    evidenceSummary: const ArchiveAnalystEvidenceSummary(
      eligibleReflectionCount: 58,
      dateSpanLabel: 'the last six weeks',
      uniqueBeliefCandidates: 3,
      contradictionCount: 1,
      blindSpotCount: 0,
    ),
    currentBeliefs: [
      ArchiveAnalystBeliefRow(
        id: 'sample-primary',
        statement: 'I take responsibility before asking for help.',
        confidencePercent: 74,
        evidenceCount: 3,
        counterEvidenceCount: 1,
        lastUpdated: DateTime(2026, 5, 25),
        isPrimary: true,
      ),
    ],
    emergingBeliefs: const [
      ArchiveAnalystTrendBelief(
        id: 'sample-emerging',
        statement: 'Pausing makes it easier to ask directly.',
        confidencePercent: 68,
        trendLabel: 'Appearing more often',
        mentionSeries: [0, 1, 2],
      ),
    ],
    fadingBeliefs: const [],
    contradictions: const [],
    blindSpots: const [],
    competingBeliefs: const [],
    debates: const [],
    primaryBeliefId: 'sample-primary',
  );

  static final sampleTimeline = ArchiveEvolutionTimeline(
    patternTitle: 'Taking responsibility before asking for help',
    firstSeenDate: DateTime(2026, 5, 4),
    lastSeenDate: DateTime(2026, 5, 25),
    eventCount: 3,
    events: [
      ArchiveEvolutionEvent(
        id: 'sample-first-seen',
        date: DateTime(2026, 5, 4),
        type: ArchiveEvolutionEventType.firstSeen,
        title: 'First seen',
        body: 'You noticed yourself saying yes before checking your capacity.',
      ),
      ArchiveEvolutionEvent(
        id: 'sample-showed-again',
        date: DateTime(2026, 5, 18),
        type: ArchiveEvolutionEventType.showedAgain,
        title: 'Showed up again',
        body: 'The same pull appeared after a work message.',
      ),
      ArchiveEvolutionEvent(
        id: 'sample-felt-lighter',
        date: DateTime(2026, 5, 25),
        type: ArchiveEvolutionEventType.feltLighter,
        title: 'Felt lighter',
        body: 'It felt lighter when you paused and asked for help.',
      ),
    ],
  );

  @override
  State<PaywallInsightPreview> createState() => _PaywallInsightPreviewState();
}

class _PaywallInsightPreviewState extends State<PaywallInsightPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final report = widget.report ?? PaywallInsightPreview.sampleReport;
    final timeline = widget.timeline ?? PaywallInsightPreview.sampleTimeline;
    final primary = report.currentBeliefs.first;
    final digest = widget.analystEngine.buildAudioDigest(report);

    return Semantics(
      container: true,
      label: 'Sample ArchiveMe Pro insight preview',
      child: Container(
        key: const Key('paywall_insight_preview'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1DCF8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Preview a Pro insight',
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try a fictional example before choosing a plan. '
              'None of your archive is used for this demo.',
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('paywall_insight_preview_toggle'),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.visibility_off_outlined
                    : Icons.auto_awesome_outlined,
              ),
              label: Text(
                _expanded ? 'Hide sample insight' : 'Show sample insight',
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AnalystSampleCard(
                      statement: primary.statement,
                      evidenceCount: primary.evidenceCount,
                      counterEvidenceCount: primary.counterEvidenceCount,
                      digest: digest,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TimelineSample(timeline: timeline),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Sample output · fictional moments',
                      key: const Key('paywall_insight_preview_disclaimer'),
                      textAlign: TextAlign.center,
                      style: ArchiveMobileTypography.responsiveHelper(
                        context,
                      ).copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalystSampleCard extends StatelessWidget {
  const _AnalystSampleCard({
    required this.statement,
    required this.evidenceCount,
    required this.counterEvidenceCount,
    required this.digest,
  });

  final String statement;
  final int evidenceCount;
  final int counterEvidenceCount;
  final String digest;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('paywall_archive_analyst_sample'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Archive Analyst',
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(statement, style: ArchiveMobileTypography.listTitle(context)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$evidenceCount supporting moments · '
              '$counterEvidenceCount counter-example',
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              digest,
              key: const Key('paywall_archive_analyst_digest'),
              style: ArchiveMobileTypography.responsiveBody(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineSample extends StatelessWidget {
  const _TimelineSample({required this.timeline});

  final ArchiveEvolutionTimeline timeline;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('paywall_evolution_timeline_sample'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5E6D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolution timeline',
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            timeline.patternTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final event in timeline.events) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.timeline_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${event.title}: ${event.body}',
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
