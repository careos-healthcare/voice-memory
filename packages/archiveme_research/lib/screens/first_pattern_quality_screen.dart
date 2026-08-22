import 'dart:async';

import 'package:flutter/material.dart';

import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/features/first_session/first_pattern_quality_result.dart';
import 'package:archiveme_mobile/features/first_session/first_pattern_quality_runner.dart';
import 'package:archiveme_mobile/features/first_session/first_pattern_quality_samples.dart';
import 'package:archiveme_mobile/features/activation/activation_summary_engine.dart';
import 'package:archiveme_mobile/features/activation/activation_summary_model.dart';
import 'package:archiveme_mobile/features/first_session/pattern_correction_learning_coordinator.dart';
import 'package:archiveme_mobile/features/first_session/pattern_correction_learning_model.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/debug_only_unavailable.dart';

/// Developer-only first-pattern QA report.
class FirstPatternQualityScreen extends StatefulWidget {
  const FirstPatternQualityScreen({super.key});

  @override
  State<FirstPatternQualityScreen> createState() =>
      _FirstPatternQualityScreenState();
}

class _FirstPatternQualityScreenState extends State<FirstPatternQualityScreen> {
  FirstPatternQualityResult? _result;
  PatternCorrectionLearningSummary? _correctionSummary;
  ActivationSummary? _activationSummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (DeveloperSettingsGate.canShowDeveloperSettings) {
      unawaited(_run());
    }
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final result = const FirstPatternQualityRunner().run(
      FirstPatternQualitySamples.all,
    );
    final correctionSummary =
        await PatternCorrectionLearningCoordinator.buildDeveloperSummary();
    final activationSummary = await const ActivationSummaryEngine().build();
    if (!mounted) return;
    setState(() {
      _result = result;
      _correctionSummary = correctionSummary;
      _activationSummary = activationSummary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const DebugOnlyUnavailableScreen(title: 'First Pattern Quality');
    }

    final result = _result;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('First Pattern Quality'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading || result == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _metricCard(
                  'Accuracy',
                  '${(result.accuracyRate * 100).toStringAsFixed(1)}%',
                  subtitle:
                      '${result.accepted} accepted · ${result.rejected} rejected · ${result.total} total',
                ),
                _metricRow('Fallback count', '${result.fallbackCount}'),
                _metricRow(
                  'Low-confidence count',
                  '${result.lowConfidenceCount}',
                ),
                _metricRow(
                  'Correction recommended',
                  '${result.correctionRecommendedCount}',
                ),
                _metricRow(
                  'Overconfident wrong',
                  '${result.overconfidentWrongCount}',
                ),
                _metricRow(
                  'Vague/neutral OK',
                  '${result.vagueFallbackAcceptedCount}/${result.vagueNeutralSampleCount}',
                ),
                _metricRow(
                  'Negation handled',
                  '${result.negationHandledCount}/${result.negationSampleCount}',
                ),
                _metricRow(
                  'Ambiguous handled',
                  '${result.ambiguousHandledCount}/${result.ambiguousSampleCount}',
                ),
                _metricRow('Hard gates pass', '${result.passesHardQaGates}'),
                const SizedBox(height: 16),
                const Text(
                  'Category breakdown (accepted)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...result.categoryBreakdown.entries.map(
                  (e) => _metricRow(e.key, '${e.value}'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failures (${result.failures.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (result.failures.isEmpty)
                  const Text(
                    'No failures — all samples matched acceptable titles.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 13),
                  )
                else
                  ...result.failures.map(_failureTile),
                const SizedBox(height: 24),
                const Text(
                  'Correction learning',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._correctionLearningSection(_correctionSummary),
                const SizedBox(height: 24),
                const Text(
                  'Watch-for prompts',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._watchForPromptSection(_activationSummary),
                const SizedBox(height: 24),
                const Text(
                  'Return capture',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._returnCaptureSection(_activationSummary),
              ],
            ),
    );
  }

  List<Widget> _returnCaptureSection(ActivationSummary? summary) {
    if (summary == null) {
      return const [
        Text('Loading…', style: TextStyle(color: AppTheme.muted, fontSize: 13)),
      ];
    }
    final selectionRate = summary.returnCaptureQuickAnswerSelectionRate;
    final recordedRate = summary.returnCaptureRecordedAfterQuickAnswerRate;
    return [
      _metricRow(
        'Quick answers selected',
        '${summary.returnCaptureQuickAnswerSelectedCount}',
      ),
      _metricRow(
        'Recorded after quick answer',
        '${summary.returnCaptureRecordedAfterSelectionCount}',
      ),
      _metricRow(
        'Skipped without answer',
        '${summary.returnCaptureSkippedCount}',
      ),
      _metricRow(
        'Selection rate',
        selectionRate == null
            ? '—'
            : '${(selectionRate * 100).toStringAsFixed(0)}%',
      ),
      _metricRow(
        'Recorded after selection rate',
        recordedRate == null
            ? '—'
            : '${(recordedRate * 100).toStringAsFixed(0)}%',
      ),
    ];
  }

  List<Widget> _watchForPromptSection(ActivationSummary? summary) {
    if (summary == null) {
      return const [
        Text('Loading…', style: TextStyle(color: AppTheme.muted, fontSize: 13)),
      ];
    }
    final rate = summary.watchForPromptAcceptanceRate;
    return [
      _metricRow(
        'Watch-for accepted',
        '${summary.watchForPromptAcceptedCount}',
      ),
      _metricRow('Watch-for shown', '${summary.watchForPromptShownCount}'),
      _metricRow(
        'Acceptance rate',
        rate == null ? '—' : '${(rate * 100).toStringAsFixed(0)}%',
      ),
    ];
  }

  List<Widget> _correctionLearningSection(
    PatternCorrectionLearningSummary? summary,
  ) {
    if (summary == null) {
      return const [
        Text('Loading…', style: TextStyle(color: AppTheme.muted, fontSize: 13)),
      ];
    }
    if (summary.totalLearned == 0) {
      return const [
        Text(
          'No corrections learned yet.',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
      ];
    }
    final widgets = <Widget>[
      _metricRow('Total corrections learned', '${summary.totalLearned}'),
      _metricRow(
        'Most corrected-to category',
        summary.mostCorrectedCategoryId.isEmpty
            ? '—'
            : summary.mostCorrectedCategoryId,
      ),
      _metricRow(
        'Most corrected-to pattern',
        summary.mostCorrectedTitle.isEmpty ? '—' : summary.mostCorrectedTitle,
      ),
      _metricRow('Used for next prompt', '${summary.usedForNextPromptCount}'),
      const SizedBox(height: 8),
      const Text(
        'Recent corrections',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      const SizedBox(height: 8),
    ];
    for (final item in summary.recent) {
      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.originalTitle} → ${item.correctedTitle}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.originalCategoryId} → ${item.correctedCategoryId}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                if (item.usedForNextPrompt)
                  const Text(
                    'Used for tomorrow',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                if (item.reflectionSnippet.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.reflectionSnippet,
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _metricCard(String title, String value, {String? subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _failureTile(FirstPatternQualityFailure failure) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failure.sampleId,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Expected: ${failure.expectedCategory}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'Actual: ${failure.actualTitle}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'Confidence: ${failure.confidenceScore.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, color: AppTheme.muted),
            ),
            const SizedBox(height: 6),
            Text(
              failure.reflectionText,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              failure.matchReason,
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
