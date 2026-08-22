import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/features/comparison/comparison_copy.dart';
import 'package:archiveme_mobile/features/comparison/comparison_engine_service.dart';
import 'package:archiveme_mobile/features/comparison/comparison_models.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_copy.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/accessibility/accessible_primary_surface.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Primary Then vs Now destination — side-by-side temporal belief comparison.
class ThenVsNowComparisonScreen extends StatefulWidget {
  const ThenVsNowComparisonScreen({super.key, this.initialRange});

  final ComparisonTemporalRange? initialRange;

  @override
  State<ThenVsNowComparisonScreen> createState() =>
      _ThenVsNowComparisonScreenState();
}

class _ThenVsNowComparisonScreenState extends State<ThenVsNowComparisonScreen> {
  ComparisonTemporalRange _range =
      ComparisonTemporalRange.thirtyDaysVsToday;
  ComparisonExplorerResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange ?? ComparisonTemporalRange.thirtyDaysVsToday;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await AppServices.instance.journal.loadAll();
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final facts = await FactLedgerStore.forPrefs(
      AppServices.instance.prefs,
    ).loadAll();
    final evolution = await AppServices.instance.beliefEvolution.loadState();

    if (!mounted) return;
    setState(() {
      _result = ComparisonEngineService.build(
        range: _range,
        entries: realEntries,
        facts: facts,
        beliefEvolution: evolution,
      );
      _loading = false;
    });
  }

  Future<void> _selectRange(ComparisonTemporalRange range) async {
    setState(() => _range = range);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AccessiblePrimarySurface(
      label: BeliefProductCopy.changesScreenTitle,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: ArchiveMobileSpacing.pagePadding,
                    children: [
                      Text(
                        ComparisonCopy.screenTitle,
                        style: VoiceMemoryTypography.headlineStyle(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        ComparisonCopy.screenLead,
                        style: VoiceMemoryTypography.bodyStyle(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 18, height: 1.45),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        ComparisonCopy.rangeSection,
                        style: VoiceMemoryTypography.sectionLabelStyle(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RangeSelector(
                        selected: _range,
                        onSelected: _selectRange,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_result == null || !_result!.hasEnoughEvidence)
                        _InsufficientCard()
                      else ...[
                        _SideBySidePanel(result: _result!),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          ComparisonCopy.shiftsSection,
                          style: VoiceMemoryTypography.sectionLabelStyle(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final shift in _result!.shifts)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _ShiftCard(shift: shift),
                          ),
                        if (_result!.droppedAssumptions.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            ComparisonCopy.droppedSection,
                            style: VoiceMemoryTypography.sectionLabelStyle(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final item in _result!.droppedAssumptions)
                                Chip(label: Text(item)),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onSelected});

  final ComparisonTemporalRange selected;
  final ValueChanged<ComparisonTemporalRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final range in ComparisonTemporalRange.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                key: Key('comparison_range_${range.name}'),
                label: Text(range.shortLabel),
                selected: selected == range,
                onSelected: (_) => onSelected(range),
              ),
            ),
        ],
      ),
    );
  }
}

class _SideBySidePanel extends StatelessWidget {
  const _SideBySidePanel({required this.result});

  final ComparisonExplorerResult result;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _PeriodColumn(snapshot: result.then, side: 'then')),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _PeriodColumn(snapshot: result.now, side: 'now')),
        ],
      );
    }

    return Column(
      children: [
        _PeriodColumn(snapshot: result.then, side: 'then'),
        const SizedBox(height: AppSpacing.md),
        _PeriodColumn(snapshot: result.now, side: 'now'),
      ],
    );
  }
}

class _PeriodColumn extends StatelessWidget {
  const _PeriodColumn({required this.snapshot, required this.side});

  final ComparisonPeriodSnapshot snapshot;
  final String side;

  @override
  Widget build(BuildContext context) {
    final title = side == 'then'
        ? ComparisonCopy.thenColumn
        : ComparisonCopy.nowColumn;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      width: double.infinity,
      decoration: VoiceMemoryCards.standard(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              snapshot.label,
              style: VoiceMemoryTypography.secondaryStyle(),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ConfidenceBadge(band: snapshot.confidenceBand),
            const SizedBox(height: AppSpacing.sm),
            Text(
              snapshot.hasBelief
                  ? '"${snapshot.beliefText}"'
                  : 'Not enough saved detail in this window.',
              style: VoiceMemoryTypography.bodyStyle().copyWith(
                height: 1.45,
                fontStyle:
                    snapshot.hasBelief ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${snapshot.entryCount} entries · ${snapshot.factCount} ledger facts · '
              '${snapshot.confidencePercent}% confidence',
              style: VoiceMemoryTypography.secondaryStyle(),
            ),
            if (snapshot.citations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                ComparisonCopy.factLedgerNote,
                style: VoiceMemoryTypography.sectionLabelStyle(),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final citation in snapshot.citations.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _CitationRow(
                    citation: citation,
                    dateLabel: dateFormat.format(citation.recordedAt),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift});

  final ComparisonBeliefShift shift;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: VoiceMemoryCards.standard(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  shift.headline,
                  style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                    fontSize: 17,
                  ),
                ),
                _ConfidenceBadge(
                  band: shift.deltaBand,
                  labelOverride: shift.deltaBadgeLabel,
                ),
              ],
            ),
            if (shift.contradictionNote != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                shift.contradictionNote!,
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  color: VoiceMemoryColors.blindSpotAmber,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Then: ${shift.thenBelief}',
              style: VoiceMemoryTypography.secondaryStyle().copyWith(
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Now: ${shift.nowBelief}',
              style: VoiceMemoryTypography.secondaryStyle().copyWith(
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              PatternMatchQualityCopy.explanationFor(shift.deltaBand),
              style: VoiceMemoryTypography.secondaryStyle(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitationRow extends StatelessWidget {
  const _CitationRow({
    required this.citation,
    required this.dateLabel,
  });

  final ComparisonCitation citation;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dateLabel,
                style: VoiceMemoryTypography.secondaryStyle().copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ActionChip(
              key: Key('comparison_citation_${citation.entryId}'),
              label: const Text(ComparisonCopy.openEntry),
              onPressed: () => context.push('/entry/${citation.entryId}'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          citation.quote,
          style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.band, this.labelOverride});

  final PatternMatchConfidenceBand band;
  final String? labelOverride;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(band);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        labelOverride ?? palette.label,
        style: VoiceMemoryTypography.bodyStyle(
          color: palette.foreground,
        ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _InsufficientCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: VoiceMemoryCards.standard(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ComparisonCopy.insufficientTitle,
              style: VoiceMemoryTypography.cardTitleStyle(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ComparisonCopy.insufficientBody,
              style: VoiceMemoryTypography.secondaryStyle().copyWith(
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BandPalette {
  const _BandPalette({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;
}

_BandPalette _paletteFor(PatternMatchConfidenceBand band) {
  return switch (band) {
    PatternMatchConfidenceBand.weak => const _BandPalette(
      label: 'Weak',
      background: VoiceMemoryColors.surfaceSecondary,
      border: VoiceMemoryColors.border,
      foreground: VoiceMemoryColors.textSecondary,
    ),
    PatternMatchConfidenceBand.emerging => _BandPalette(
      label: 'Emerging',
      background: VoiceMemoryColors.discoveryGoldBackground,
      border: VoiceMemoryColors.blindSpotAmber.withValues(alpha: 0.45),
      foreground: VoiceMemoryColors.blindSpotAmber,
    ),
    PatternMatchConfidenceBand.solid => _BandPalette(
      label: 'Solid',
      background: VoiceMemoryColors.beliefIndigo.withValues(alpha: 0.1),
      border: VoiceMemoryColors.beliefIndigo.withValues(alpha: 0.35),
      foreground: VoiceMemoryColors.beliefIndigo,
    ),
    PatternMatchConfidenceBand.strong => _BandPalette(
      label: 'Strong',
      background: VoiceMemoryColors.success.withValues(alpha: 0.12),
      border: VoiceMemoryColors.success.withValues(alpha: 0.4),
      foreground: VoiceMemoryColors.success,
    ),
  };
}