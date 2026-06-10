import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../billing/archive_entitlement_reader.dart';
import '../billing/paywall_route_args.dart';
import '../billing/paywall_source.dart';
import '../design/archive_mobile_typography.dart';
import '../features/pressure_retention/archive_reflection_engine.dart';
import '../features/pressure_retention/pressure_check_in_record.dart';
import '../features/pressure_retention/pressure_check_in_store.dart';
import '../features/pressure_retention/pressure_evidence_confidence.dart';
import '../features/pressure_retention/pressure_loop_visibility_engine.dart';
import '../features/pressure_retention/pressure_micro_experiment_store.dart';
import '../features/pressure_retention/pressure_pattern_reveal_engine.dart';
import '../features/pressure_retention/pressure_pattern_reveal_model.dart';
import '../features/pressure_retention/pressure_pattern_review_engine.dart';
import '../features/pressure_retention/pressure_pattern_review_model.dart';
import '../features/pressure_retention/pressure_personal_evidence_summary_engine.dart';
import '../features/pressure_retention/pressure_report_builder.dart';
import '../features/pressure_retention/pressure_return_trigger_engine.dart';
import '../features/pressure_retention/pressure_return_trigger_model.dart';
import '../features/pressure_retention/pressure_return_trigger_store.dart';
import '../features/pressure_retention/pressure_weekly_recap_engine.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pressure_retention/ask_the_archive_card.dart';
import '../widgets/pressure_retention/pressure_first_week_nudge.dart';
import '../widgets/pressure_retention/pressure_insights_empty_state.dart';
import '../widgets/pressure_retention/pressure_loop_visibility_card.dart';
import '../widgets/pressure_retention/pressure_micro_experiment_card.dart';
import '../widgets/pressure_retention/pressure_pattern_reveal_card.dart';
import '../widgets/pressure_retention/pressure_pattern_review_card.dart';
import '../widgets/pressure_retention/pressure_personal_evidence_summary_card.dart';
import '../widgets/pressure_retention/pressure_pro_upgrade_card.dart';
import '../widgets/pressure_retention/pressure_report_share_button.dart';
import '../widgets/pressure_retention/pressure_return_trigger_card.dart';
import '../widgets/pressure_retention/pressure_weekly_recap_card.dart';

/// Pressure loop screen: weekly visibility, recap, and the focused reflection.
///
/// The free loop is never blocked — free users can always log moments and see
/// a basic loop card plus a limited recap preview. Pro unlocks the full
/// visibility, the full recap, Ask the Archive, evidence confidence, and a
/// shareable pressure report.
class PressureInsightsScreen extends StatefulWidget {
  const PressureInsightsScreen({
    super.key,
    this.store,
    this.entitlementReader,
    this.microExperimentStore,
    this.returnTriggerStore,
    @visibleForTesting this.records,
  });

  final PressureCheckInStore? store;

  /// Injectable Pro reader; defaults to the live entitlement check.
  final ArchiveEntitlementReader? entitlementReader;

  /// Injectable store for the micro-experiment accepted flag.
  final PressureMicroExperimentStore? microExperimentStore;

  /// Injectable store for the return trigger accepted/dismissed state.
  final PressureReturnTriggerStore? returnTriggerStore;

  /// Injected for tests; production loads from [PressureCheckInStore].
  @visibleForTesting
  final List<PressureCheckInRecord>? records;

  @override
  State<PressureInsightsScreen> createState() => _PressureInsightsScreenState();
}

class _PressureInsightsScreenState extends State<PressureInsightsScreen> {
  static const _visibilityEngine = PressureLoopVisibilityEngine();
  static const _recapEngine = PressureWeeklyRecapEngine();
  static const _reflectionEngine = ArchiveReflectionEngine();
  static const _confidenceEngine = PressureEvidenceConfidenceEngine();
  static const _reportBuilder = PressureReportBuilder();
  static const _patternEngine = PressurePatternRevealEngine();
  static const _reviewEngine = PressurePatternReviewEngine();
  static const _personalEvidenceEngine = PressurePersonalEvidenceSummaryEngine();
  static const _returnTriggerEngine = PressureReturnTriggerEngine();

  late Future<_InsightsData> _future;

  bool _showMicroExperiment = false;
  bool _experimentAccepted = false;
  PressureReturnTriggerStatus? _triggerOverride;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  PressureMicroExperimentStore? get _experimentStore =>
      widget.microExperimentStore ??
      (AppServices.isInitialized
          ? PressureMicroExperimentStore.instance()
          : null);

  PressureReturnTriggerStore? get _triggerStore =>
      widget.returnTriggerStore ??
      (AppServices.isInitialized ? PressureReturnTriggerStore.instance() : null);

  Future<void> _acceptExperiment() async {
    await _experimentStore?.markAccepted();
    if (!mounted) return;
    setState(() => _experimentAccepted = true);
  }

  Future<void> _acceptReturnTrigger() async {
    await _triggerStore?.markAccepted();
    if (!mounted) return;
    setState(() => _triggerOverride = PressureReturnTriggerStatus.accepted);
  }

  Future<void> _dismissReturnTrigger() async {
    await _triggerStore?.markDismissed();
    if (!mounted) return;
    setState(() => _triggerOverride = PressureReturnTriggerStatus.dismissed);
  }

  Future<_InsightsData> _load() async {
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    final records = widget.records ??
        await (widget.store ?? PressureCheckInStore.instance()).loadAll();
    final experimentAccepted = await _experimentStore?.accepted ?? false;
    final triggerAccepted = await _triggerStore?.accepted ?? false;
    final triggerDismissed = await _triggerStore?.dismissed ?? false;
    return _InsightsData(
      records: records,
      isPro: isPro,
      experimentAccepted: experimentAccepted,
      triggerAccepted: triggerAccepted,
      triggerDismissed: triggerDismissed,
    );
  }

  void _openPaywall(
    String title,
    String body, {
    PaywallSource source = PaywallSource.generalPro,
  }) {
    context.push(
      '/subscription',
      extra: PaywallRouteArgs(
        previewTitle: title,
        previewBody: body,
        sourceRoute: '/pressure-insights',
        source: source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Your pressure loop'),
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<_InsightsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ??
                const _InsightsData(records: [], isPro: false);
            return _buildContent(context, data);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _InsightsData data) {
    final records = data.records;
    final isPro = data.isPro;

    // Not enough data yet: replace the cards with a single clear next step.
    if (records.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What your pressure loop looks like',
              style: ArchiveMobileTypography.responsivePageTitle(context),
            ),
            const SizedBox(height: AppSpacing.md),
            PressureInsightsEmptyState(
              onLogPressure: () => context.push('/pressure-check-in'),
            ),
          ],
        ),
      );
    }

    final visibility = _visibilityEngine.build(records);
    final recap = _recapEngine.build(records);
    final confidence = _confidenceEngine.fromRecords(records);

    final children = <Widget>[
      Text(
        'What your pressure loop looks like',
        style: ArchiveMobileTypography.responsivePageTitle(context),
      ),
      const SizedBox(height: AppSpacing.md),
      if (records.length <= 2) ...[
        const PressureFirstWeekNudge(),
        const SizedBox(height: AppSpacing.sm),
      ],
      // Personal evidence first: why the pattern below is believed to exist.
      // Free and Pro both see it; renders only with enough repeated evidence.
      ..._personalEvidenceSection(records),
      if (records.length >= PressurePatternReveal.minEntries) ...[
        PressurePatternRevealCard(
          reveal: _patternEngine.build(records),
          isPro: isPro,
          onTryInterruption: () =>
              setState(() => _showMicroExperiment = true),
          onUnlock: () => _openPaywall(
            'Unlock full pattern history',
            'Pro keeps your full pressure pattern history across weeks and '
                'months.',
            source: PaywallSource.pressurePatternHistory,
          ),
        ),
        if (_showMicroExperiment) ...[
          const SizedBox(height: AppSpacing.sm),
          PressureMicroExperimentCard(
            accepted: _experimentAccepted,
            onAccept: _acceptExperiment,
            onDismiss: () => setState(() => _showMicroExperiment = false),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
      if (records.length >= PressurePatternReview.minEntries) ...[
        PressurePatternReviewCard(
          review: _reviewEngine.build(records),
          isPro: isPro,
          onUnlock: () => _openPaywall(
            'Unlock full review',
            'Your full pressure review — costs, changes, and next week\'s '
                'experiment — is part of ArchiveMe Pro.',
            source: PaywallSource.pressureReview,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      ..._returnTriggerSection(data),
      PressureLoopVisibilityCard(
        visibility: visibility,
        locked: !isPro,
        confidence: isPro ? confidence : null,
      ),
      const SizedBox(height: AppSpacing.sm),
      PressureWeeklyRecapCard(recap: recap, locked: !isPro),
    ];

    if (!isPro) {
      children
        ..add(const SizedBox(height: AppSpacing.sm))
        ..add(PressureProUpgradeCard(
          title: 'Unlock your full pressure pattern',
          body: 'See where this keeps repeating, week after week.',
          onUnlock: () => _openPaywall(
            'Unlock your full pressure pattern',
            'See where this keeps repeating, week after week.',
            source: PaywallSource.pressurePatternHistory,
          ),
        ))
        ..add(const SizedBox(height: AppSpacing.sm))
        ..add(PressureProUpgradeCard(
          title: 'Ask your archive what this pressure is trying to prove',
          body: 'Pro turns your saved moments into evidence-based answers.',
          onUnlock: () => _openPaywall(
            'Ask your archive what this pressure is trying to prove',
            'Pro turns your saved moments into evidence-based answers.',
            source: PaywallSource.askArchive,
          ),
        ));
    }

    children
      ..add(const SizedBox(height: AppSpacing.sm))
      ..add(AskTheArchiveCard(
        records: records,
        engine: _reflectionEngine,
        locked: !isPro,
        onUnlock: () => _openPaywall(
          'Ask your archive what this pressure is trying to prove',
          'Pro turns your saved moments into evidence-based answers.',
          source: PaywallSource.askArchive,
        ),
      ));

    if (isPro) {
      children
        ..add(const SizedBox(height: AppSpacing.sm))
        ..add(PressureReportShareButton(
          reportText: _reportBuilder.toText(
            records: records,
            visibility: visibility,
            recap: recap,
            confidence: confidence,
          ),
        ));
    } else {
      children
        ..add(const SizedBox(height: AppSpacing.sm))
        ..add(PressureProUpgradeCard(
          title: 'Keep the evidence trail, not just the moment',
          body: 'Pro keeps your full pressure report across weeks and months.',
          onUnlock: () => _openPaywall(
            'Keep the evidence trail, not just the moment',
            'Pro keeps your full pressure report across weeks and months.',
          ),
        ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// Return trigger card, below the reveal/review/micro-experiment area.
  /// "Why this may be your pattern" — only when the user's own entries hold
  /// enough repeated evidence (3+ entries with real repetition).
  List<Widget> _personalEvidenceSection(List<PressureCheckInRecord> records) {
    final summary = _personalEvidenceEngine.build(records);
    if (!summary.hasSummary) return const [];
    return [
      PressurePersonalEvidenceSummaryCard(summary: summary),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// Session taps (accept/dismiss, accepting the experiment) override the
  /// loaded state so the card responds immediately.
  List<Widget> _returnTriggerSection(_InsightsData data) {
    final trigger = _triggerOverride != null
        ? PressureReturnTrigger(status: _triggerOverride!)
        : _returnTriggerEngine.build(
            entryCount: data.records.length,
            experimentAccepted: data.experimentAccepted || _experimentAccepted,
            accepted: data.triggerAccepted,
            dismissed: data.triggerDismissed,
          );
    if (!trigger.show) return const [];
    return [
      PressureReturnTriggerCard(
        trigger: trigger,
        isPro: data.isPro,
        onAccept: _acceptReturnTrigger,
        onDismiss: _dismissReturnTrigger,
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
  }
}

class _InsightsData {
  const _InsightsData({
    required this.records,
    required this.isPro,
    this.experimentAccepted = false,
    this.triggerAccepted = false,
    this.triggerDismissed = false,
  });

  final List<PressureCheckInRecord> records;
  final bool isPro;
  final bool experimentAccepted;
  final bool triggerAccepted;
  final bool triggerDismissed;
}
