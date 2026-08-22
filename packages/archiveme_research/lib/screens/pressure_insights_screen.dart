import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/billing/pro_retention_check.dart';
import 'package:archiveme_mobile/billing/value_moment_paywall_trigger.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_relevance_gate.dart';
import 'package:archiveme_mobile/features/memory/memory_relevance_model.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_connection_rules.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/archive_proof_counter_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/archive_proof_counter_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/archive_reflection_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/guided_thread_plan_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_evidence_confidence.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_insights_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_loop_visibility_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_micro_experiment_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_reveal_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_reveal_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_review_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_review_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_personal_evidence_summary_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_report_builder.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_return_trigger_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_return_trigger_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_return_trigger_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_weekly_recap_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/features/aha/aha_moment_engine.dart';
import 'package:archiveme_mobile/features/aha/aha_moment_store.dart';
import 'package:archiveme_mobile/widgets/aha/first_aha_moment_card.dart';
import 'package:archiveme_mobile/widgets/share/aha_proof_share_card.dart';
import 'package:archiveme_mobile/features/trust/aha_proof_share_eligibility.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/memory/memory_relevance_chip.dart';
import 'package:archiveme_mobile/widgets/memory/memory_scope_control.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/archive_proof_counter_card.dart';
import 'package:archiveme_mobile/widgets/billing/pro_retention_check_card.dart';
import 'package:archiveme_mobile/widgets/billing/value_moment_pro_bridge.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/ask_the_archive_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/belief_distance_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/guided_thread_plan_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_first_week_nudge.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_insights_empty_state.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_loop_visibility_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_micro_experiment_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_pattern_reveal_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_pattern_review_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_personal_evidence_summary_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_pro_upgrade_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_report_share_button.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_return_trigger_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_weekly_recap_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/shareable_archive_proof_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/weekly_thread_review_card.dart';
import 'package:archiveme_mobile/widgets/referral/referral_invite_card.dart';
import 'package:archiveme_mobile/widgets/review/review_prompt_card.dart';
import 'package:archiveme_mobile/widgets/share/archive_belief_share_card_widget.dart';

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
  static const _personalEvidenceEngine =
      PressurePersonalEvidenceSummaryEngine();
  static const _returnTriggerEngine = PressureReturnTriggerEngine();
  static const _threadReturnEngine = ThreadReturnEvidenceEngine();
  static const _guidedPlanEngine = GuidedThreadPlanEngine();
  static const _beliefDistanceEngine = BeliefDistanceEngine();
  static const _proofCounterEngine = ArchiveProofCounterEngine();
  static const _weeklyReviewEngine = WeeklyThreadReviewEngine();
  static const _shareableProofEngine = ShareableArchiveProofEngine();
  static const _valueMomentTrigger = ValueMomentPaywallTrigger();
  static const _relevanceGate = MemoryRelevanceGate();

  late Future<_InsightsData> _future;

  bool _showMicroExperiment = false;
  bool _experimentAccepted = false;

  /// The user marked the archive connection "Not related" during this
  /// screen instance — keeps the confirmation visible after the rebuild.
  bool _markedNotRelatedNow = false;
  PressureReturnTriggerStatus? _triggerOverride;

  /// Decided once per screen instance so the check (and its answer ack)
  /// survives rebuilds; the session flag stops later instances.
  bool? _proRetentionEligible;

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
      (AppServices.isInitialized
          ? PressureReturnTriggerStore.instance()
          : null);

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
    // Persisted memory scope first: the engines below must already know
    // whether connection claims are allowed at all. Injected records
    // (tests/previews) control the policy directly instead.
    if (widget.records == null && AppServices.isInitialized) {
      await MemoryScopeStore.instance().ensureLoaded();
      // Per-card connection rules (keep connected / future-fresh) ride
      // along with scope: loaded before any framing happens.
      await MemoryConnectionRuleStore.instance().ensureLoaded();
      await WrongThreadFeedbackStore.instance().ensureLoaded();
      await AhaMomentStore.ensureLoaded();
    }
    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    final records =
        widget.records ??
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
    return FutureBuilder<_InsightsData>(
      future: _future,
      builder: (context, snapshot) {
        final entryCount = snapshot.data?.records.length ?? 0;
        final screenTitle = snapshot.connectionState == ConnectionState.done
            ? PressureInsightsCopy.screenTitle(entryCount)
            : PressureInsightsCopy.screenTitleEarly;

        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          appBar: AppBar(
            title: Text(screenTitle),
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
          ),
          body: SafeArea(
            child: snapshot.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(
                    context,
                    snapshot.data ??
                        const _InsightsData(records: [], isPro: false),
                  ),
          ),
        );
      },
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
              PressureInsightsCopy.pageTitle(records.length),
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
    final proofCounter = _proofCounterEngine.build(records);

    // Memory relevance gate: the archive may only interpret the present
    // when an evidence engine already supports the connection, and the
    // user's session choices (not related / treat as new / save without
    // connecting) always win. Memory is evidence, not gravity.
    final relevance = _relevanceGate.assess(records);
    final showMemoryCards = MemoryRelevanceGate.allowMemoryCards(relevance);

    final children = <Widget>[
      Text(
        PressureInsightsCopy.pageTitle(records.length),
        style: ArchiveMobileTypography.responsivePageTitle(context),
      ),
      const SizedBox(height: AppSpacing.md),
      // Memory off: a calm notice instead of connection claims. Entries
      // stay saved; the engines above already return no claims.
      if (!MemoryScopePolicy.memoryClaimsAllowed) ...[
        MemoryOffNotice(onChangeSetting: () => context.push('/settings')),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (records.length <= 2) ...[
        const PressureFirstWeekNudge(),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (records.length == 1) ...[
        FilledButton.icon(
          key: const Key('pressure_insights_add_moment_cta'),
          onPressed: () => context.push('/pressure-check-in'),
          icon: const Icon(Icons.bolt_outlined),
          label: const Text(PressureInsightsCopy.addMomentCtaEarly),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      // Compact proof that evidence is accumulating — counts only, built from
      // the same thread detection as the evidence card below it.
      ..._proofCounterSection(records),
      // Privacy-safe share card right next to the proof counter — counts
      // only, never user text. Renders nothing without a connected thread.
      ..._shareableProofSection(records),
      // Relevance label above the memory cards: cautious for "possible",
      // confident only when engines already hold the evidence, and the
      // place to mark the connection "Not related".
      ..._memoryRelevanceSection(relevance),
      if (showMemoryCards) ...[
        // First honest aha — only when stronger memory cards are absent.
        ..._ahaMomentSection(records),
        // Thread continuity first: evidence that a real thread is being
        // tracked over time. Renders only when a thread actually repeated.
        ..._threadReturnSection(records),
        // The guided plan turns that evidence into a light "yesterday →
        // today" structure with one small next recording.
        ..._guidedPlanSection(records),
        // A repeated belief-like phrase in the user's own words, with
        // gentle distance from it. Renders only when safely formed.
        ..._beliefDistanceSection(records),
        // Compact weekly review: what returned, faded, or changed across
        // the archive this week. Renders only when something moved.
        ..._weeklyReviewSection(records),
      ],
      // Pro retention check: one optional two-tap question for Pro users
      // who genuinely saw a Pro-value surface above. Never a cancellation
      // flow; manage/cancel info stays where it already is.
      ..._proRetentionSection(records, isPro),
      // Referral invite: only after a real value moment, always below the
      // value cards it follows. Copy-to-clipboard only — nothing from the
      // archive is ever shared.
      ReferralInviteSection(
        entryCount: records.length,
        hasWeeklyReview: _weeklyReviewEngine.build(records).hasReview,
        hasConnectedProofCounter:
            proofCounter.hasProof &&
            proofCounter.connectedCount >=
                ArchiveProofCounter.minConnectedEntries,
      ),
      // App Store review prompt: only after a real value moment, once per
      // session and once ever. One CTA into the native review abstraction
      // and a clear "Not now" — never a gate, never a follow-up.
      ReviewPromptSection(
        entryCount: records.length,
        hasWeeklyReview: _weeklyReviewEngine.build(records).hasReview,
      ),
      // User-approved belief share card: only after a real value moment,
      // always below the value cards it follows. The user picks a fixed
      // generalized line — nothing from the archive can enter the card.
      ArchiveBeliefShareSection(
        hasBeliefDistance: _beliefDistanceEngine.build(records).hasBelief,
        hasWeeklyReview: _weeklyReviewEngine.build(records).hasReview,
        hasThreadReturn: _threadReturnEngine.build(records).hasEvidence,
      ),
      // Small dismissible Pro bridge — only after a real value moment, and
      // only below the evidence it refers to. Never blocks anything.
      ..._valueMomentSection(records, isPro),
      // Personal evidence next: why the pattern below is believed to exist.
      // Free and Pro both see it; renders only with enough repeated evidence.
      ..._personalEvidenceSection(records),
      if (records.length >= PressurePatternReveal.minEntries) ...[
        PressurePatternRevealCard(
          reveal: _patternEngine.build(records),
          isPro: isPro,
          onTryInterruption: () => setState(() => _showMicroExperiment = true),
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
            'See your full pressure review',
            'Your full pressure review — costs, changes, and next week\'s '
                'experiment — continues with ArchiveMe Pro.',
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
        entryCount: records.length,
      ),
      const SizedBox(height: AppSpacing.sm),
      PressureWeeklyRecapCard(
        recap: recap,
        locked: !isPro,
        entryCount: records.length,
      ),
    ];

    if (!isPro) {
      children
        ..add(const SizedBox(height: AppSpacing.sm))
        ..add(
          PressureProUpgradeCard(
            title: 'See more of your pressure pattern',
            body: 'See where this keeps repeating, week after week.',
            onUnlock: () => _openPaywall(
              'See more of your pressure pattern',
              'See where this keeps repeating, week after week.',
              source: PaywallSource.pressurePatternHistory,
            ),
          ),
        )
        ..add(const SizedBox(height: AppSpacing.sm))
        ..add(
          PressureProUpgradeCard(
            title: 'Ask your archive what this pressure is trying to prove',
            body: 'Pro turns your saved moments into evidence-based answers.',
            onUnlock: () => _openPaywall(
              'Ask your archive what this pressure is trying to prove',
              'Pro turns your saved moments into evidence-based answers.',
              source: PaywallSource.askArchive,
            ),
          ),
        );
    }

    children
      ..add(const SizedBox(height: AppSpacing.sm))
      ..add(
        AskTheArchiveCard(
          records: records,
          engine: _reflectionEngine,
          locked: !isPro,
          onUnlock: () => _openPaywall(
            'Ask your archive what this pressure is trying to prove',
            'Pro turns your saved moments into evidence-based answers.',
            source: PaywallSource.askArchive,
          ),
        ),
      );

    if (isPro) {
      children
        ..add(const SizedBox(height: AppSpacing.sm))
        ..add(
          PressureReportShareButton(
            reportText: _reportBuilder.toText(
              records: records,
              visibility: visibility,
              recap: recap,
              confidence: confidence,
            ),
          ),
        );
    } else {
      children
        ..add(const SizedBox(height: AppSpacing.sm))
        ..add(
          PressureProUpgradeCard(
            title: 'Keep the evidence trail, not just the moment',
            body:
                'Pro keeps your full pressure report across weeks and months.',
            onUnlock: () => _openPaywall(
              'Keep the evidence trail, not just the moment',
              'Pro keeps your full pressure report across weeks and months.',
            ),
          ),
        );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// Compact archive-proof counter — only when a thread genuinely connects
  /// 2+ entries. Never replaces or hides the evidence cards below it.
  List<Widget> _proofCounterSection(List<PressureCheckInRecord> records) {
    final counter = _proofCounterEngine.build(records);
    if (!counter.hasProof) return const [];
    return [
      ArchiveProofCounterCard(counter: counter),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// Pro bridge after a value moment. Dismissal hides it for the session.
  List<Widget> _valueMomentSection(
    List<PressureCheckInRecord> records,
    bool isPro,
  ) {
    final bridge = _valueMomentTrigger.build(records, isPro: isPro);
    if (!bridge.show) return const [];
    return [
      ValueMomentProBridge(
        bridge: bridge,
        onSeePro: () => _openPaywall(
          ValueMomentBridge.title,
          bridge.body,
          source: PaywallSource.valueMoment,
        ),
        onDismiss: () => setState(
          () => ValueMomentPaywallTrigger.dismissedThisSession = true,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// Anonymous share card — counts only, no user text. Renders nothing
  /// without a connected thread.
  List<Widget> _shareableProofSection(List<PressureCheckInRecord> records) {
    final proof = _shareableProofEngine.build(records);
    if (!proof.hasProof) return const [];
    return [
      ShareableArchiveProofCard(proof: proof),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// Relevance chip for possible/strong connections, or the "treated as
  /// separate" confirmation right after a Not related tap. Fresh and weak
  /// relevance render nothing — no archive-based interpretation at all.
  List<Widget> _memoryRelevanceSection(MemoryRelevanceAssessment relevance) {
    if (MemoryRelevanceGate.bypassThisSession) return const [];
    final suppressed = MemoryRelevanceGate.isNotRelated(
      MemoryRelevanceGate.insightsConnectionId,
    );
    // Suppressed on a previous screen: stay silent for the session.
    if (suppressed && !_markedNotRelatedNow) return const [];
    if (!suppressed &&
        relevance.relevance != MemoryRelevance.possible &&
        relevance.relevance != MemoryRelevance.strong) {
      return const [];
    }
    return [
      MemoryRelevanceChip(
        assessment: relevance,
        marked: suppressed,
        onMarkedNotRelated: () => setState(() => _markedNotRelatedNow = true),
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// First honest archive aha — suppressed when thread return, belief
  /// distance, or weekly review already render on this screen.
  List<Widget> _ahaMomentSection(List<PressureCheckInRecord> records) {
    final entryCount = records.length;
    final stronger = AhaMomentEngine.hasStrongerMemoryCard(
      records: records,
      entryCount: entryCount,
    );
    final candidate = const AhaMomentEngine().evaluate(
      records: records,
      entryCount: entryCount,
      hasStrongerMemoryCardVisible: stronger,
      source: 'insights',
      trackAnalytics: false,
    );
    if (!AhaMomentGates.shouldShow(
      candidate: candidate,
      entryCount: entryCount,
    )) {
      return const [];
    }
    return [
      FirstAhaMomentCard(
        candidate: candidate!,
        source: 'insights',
        onChanged: () => setState(() {}),
      ),
      if (AhaProofShareEligibility.shouldShow) ...[
        const SizedBox(height: AppSpacing.sm),
        AhaProofShareCard(
          entryCount: entryCount,
          source: 'insights',
          onDismiss: () => setState(() {}),
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// Return trigger card, below the reveal/review/micro-experiment area.
  /// Thread continuity card — only when a thread genuinely repeated across
  /// the user's entries. Shows nothing otherwise.
  List<Widget> _threadReturnSection(List<PressureCheckInRecord> records) {
    final evidence = _threadReturnEngine.build(records);
    if (!evidence.hasEvidence) return const [];
    return [
      ThreadReturnEvidenceCard(evidence: evidence),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// Guided thread plan — directly under the thread evidence it is built
  /// from. Shows nothing without enough related entries.
  List<Widget> _guidedPlanSection(List<PressureCheckInRecord> records) {
    final plan = _guidedPlanEngine.build(records);
    if (!plan.hasPlan) return const [];
    return [
      GuidedThreadPlanCard(plan: plan),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// Belief distance — only when the user's own notes hold a genuinely
  /// repeated belief-like phrase. Shows nothing otherwise.
  List<Widget> _beliefDistanceSection(List<PressureCheckInRecord> records) {
    final belief = _beliefDistanceEngine.build(records);
    if (!belief.hasBelief) return const [];
    return [
      BeliefDistanceCard(belief: belief),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// Pro retention check — Pro users only, and only when at least one
  /// Pro-value surface above genuinely rendered. Eligibility is decided
  /// once per screen instance; the session flag stops later instances.
  List<Widget> _proRetentionSection(
    List<PressureCheckInRecord> records,
    bool isPro,
  ) {
    final counter = _proofCounterEngine.build(records);
    final evidence = _threadReturnEngine.build(records);
    final cardType = ProRetentionCheck.valueSurfaceCardType(
      hasWeeklyReview: _weeklyReviewEngine.build(records).hasReview,
      hasBeliefDistance: _beliefDistanceEngine.build(records).hasBelief,
      hasThreadReturnEvidence: evidence.hasEvidence,
      hasConnectedProofCounter:
          counter.hasProof &&
          counter.connectedCount >= ArchiveProofCounter.minConnectedEntries,
    );
    _proRetentionEligible ??= ProRetentionCheck.shouldShow(
      isPro: isPro,
      cardType: cardType,
    );
    if (!_proRetentionEligible! || cardType == null) return const [];
    return [
      ProRetentionCheckCard(
        cardType: cardType,
        entryCount: records.length,
        hasConnectedThread: evidence.hasEvidence,
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

  /// Weekly thread review — what returned, faded, or changed over the last
  /// 7 days. Shows nothing without enough evidence or genuine movement.
  List<Widget> _weeklyReviewSection(List<PressureCheckInRecord> records) {
    final review = _weeklyReviewEngine.build(records);
    if (!review.hasReview) return const [];
    return [
      WeeklyThreadReviewCard(review: review),
      const SizedBox(height: AppSpacing.sm),
    ];
  }

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
