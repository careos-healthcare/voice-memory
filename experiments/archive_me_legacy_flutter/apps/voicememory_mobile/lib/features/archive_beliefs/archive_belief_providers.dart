import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../billing/archive_entitlement_reader.dart';
import '../../config/experimental_features.dart';
import '../../design/empty_archive_experience.dart';
import '../../models/journal_entry.dart';
import '../../services/app_services_providers.dart';
import '../activation/archive_workspace_hint_store.dart';
import '../archive_backup_bridge/archive_backup_bridge_dismiss_store.dart';
import '../archive_evidence/archive_belief_correction_store.dart';
import '../archive_daily_change/archive_daily_change_store.dart';
import '../archive_growth/archive_growth_service.dart';
import '../beta/beta_activation_loop_counts.dart';
import '../beta/beta_activation_loop_tracker.dart';
import '../beta/confirmed_repeat_beta_feedback_store.dart';
import '../beta/core_value_feedback_store.dart';
import '../beta_feedback/beta_feedback_store.dart';
import '../beta_feedback_capture/beta_feedback_capture_store.dart';
import '../beta_invite/beta_invite_store.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import '../beta_repair_lab/beta_repair_lab_store.dart';
import '../capacity_loop/capacity_activation_fit_store.dart';
import '../capacity_loop/capacity_beta_mission_store.dart';
import '../capacity_loop/capacity_boundary_response_store.dart';
import '../capacity_loop/capacity_cost_store.dart';
import '../capacity_loop/capacity_decision_outcome_store.dart';
import '../capacity_loop/capacity_pull_reason_store.dart';
import '../correction_memory/correction_memory_store.dart';
import '../current_relevance/current_relevance_store.dart';
import '../discover/discover_local.dart';
import '../early_archive/confirmed_repeat_thought_map_store.dart';
import '../early_archive/confirmed_repeat_why_matters_store.dart';
import '../entry_importance/entry_importance_store.dart';
import '../insights/archive_insight.dart';
import '../monthly_private_report/monthly_private_report_dismiss_store.dart';
import '../onboarding/record_return_pro_store.dart';
import '../onboarding/record_return_pro_state.dart';
import '../pattern_naming/pattern_name_store.dart';
import '../pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import '../pro_interest/pro_interest_store.dart';
import '../pro_understanding_lift/pro_understanding_lift_store.dart';
import '../pro/pro_value_preview_dismiss_store.dart';
import '../pro_visibility_lift/pro_visibility_lift_store.dart';
import '../repeat_return_check/pattern_changed_store.dart';
import '../repeat_return_check/repeat_return_check_store.dart';
import '../review_ritual/view_ritual_store.dart';
import 'archive_belief_models.dart';
import 'archive_beliefs_presenter.dart';
import 'belief_change_timeline.dart';

final archiveBootstrapProvider =
    AsyncNotifierProvider.autoDispose<
      ArchiveBootstrapController,
      ArchiveBootstrapSnapshot
    >(ArchiveBootstrapController.new);

class ArchiveBootstrapSnapshot {
  const ArchiveBootstrapSnapshot({
    required this.entries,
    required this.isPro,
    required this.betaActivationLoopCounts,
    required this.proBridgeResolved,
    required this.beliefs,
    required this.changing,
    required this.insights,
  });

  final List<JournalEntry> entries;
  final bool isPro;
  final BetaActivationLoopCounts betaActivationLoopCounts;
  final bool proBridgeResolved;
  final ArchiveBeliefsSnapshot? beliefs;
  final List<BeliefChangeTimelineItem> changing;
  final ArchiveInsightsSnapshot insights;
}

class ArchiveBootstrapController
    extends AsyncNotifier<ArchiveBootstrapSnapshot> {
  Future<ArchiveBootstrapSnapshot>? _pending;

  @override
  Future<ArchiveBootstrapSnapshot> build() => _startLoad();

  Future<ArchiveBootstrapSnapshot> refresh() async {
    final pending = _pending;
    if (pending != null) return pending;
    state = const AsyncLoading<ArchiveBootstrapSnapshot>();
    final result = await _startLoad();
    if (ref.mounted) state = AsyncData(result);
    return result;
  }

  Future<ArchiveBootstrapSnapshot> _startLoad() {
    final future = _load();
    _pending = future;
    future.whenComplete(() {
      if (identical(_pending, future)) _pending = null;
    });
    return future;
  }

  Future<ArchiveBootstrapSnapshot> _load() async {
    if (!enableExperimentalFeatures) return _loadFocusedV1();

    await PatternNameStore.ensureLoaded();
    await ArchiveBeliefCorrectionStore.ensureLoaded();
    await ArchiveWorkspaceHintStore.ensureLoaded();
    await ProValuePreviewDismissStore.ensureLoaded();
    await ProEvidenceValueDismissStore.ensureLoaded();
    await ProVisibilityLiftStore.ensureLoaded();
    await ProUnderstandingLiftStore.ensureLoaded();
    await BetaRepairLabStore.ensureLoaded();
    await MonthlyPrivateReportDismissStore.ensureLoaded();
    await ArchiveBackupBridgeDismissStore.ensureLoaded();
    await BetaFeedbackStore.ensureLoaded();
    await ConfirmedRepeatBetaFeedbackStore.ensureLoaded();
    await CoreValueFeedbackStore.ensureLoaded();
    await BetaProofFeedbackStore.ensureLoaded();
    await BetaFeedbackCaptureStore.ensureLoaded();
    await BetaInviteLoopDismissStore.ensureLoaded();
    await ConfirmedRepeatWhyMattersStore.ensureLoaded();
    await ConfirmedRepeatThoughtMapStore.ensureLoaded();
    await RepeatReturnCheckStore.ensureLoaded();
    await CurrentRelevanceStore.ensureLoaded();
    await CorrectionMemoryStore.ensureLoaded();
    await EntryImportanceStore.ensureLoaded();
    await PatternChangedStore.ensureLoaded();
    await ReviewRitualStore.ensureLoaded();
    await CapacityCostStore.ensureLoaded();
    await CapacityDecisionOutcomeStore.ensureLoaded();
    await CapacityPullReasonStore.ensureLoaded();
    await CapacityActivationFitStore.ensureLoaded();
    await CapacityBoundaryResponseStore.ensureLoaded();
    await ArchiveDailyChangeStore.ensureLoaded();
    await CapacityBetaMissionStore.ensureLoaded();
    await ProInterestStore.ensureLoaded();

    final entitlement = ArchiveEntitlementReader.forAccessCheck().isPro;
    final proBridge = RecordReturnProStore.instance().load();
    final betaCounts = BetaActivationLoopTracker.readCounts();
    final entries = ref.read(journalServiceProvider).loadAll();
    final resolved = await Future.wait<Object>([
      entitlement,
      proBridge,
      betaCounts,
      entries,
    ]);

    final isPro = resolved[0] as bool;
    final loadedEntries = resolved[3] as List<JournalEntry>;
    ArchiveBeliefsSnapshot? beliefs;
    var changing = const <BeliefChangeTimelineItem>[];
    var insights = ArchiveInsightsSnapshot.empty;
    if (loadedEntries.length >= 2 &&
        !isIntentionalEmptyArchive(loadedEntries)) {
      final baselineRaw = await ref.read(prefsProvider).discoverBaseline;
      final baselineMap = baselineRaw?.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
      final feed = DiscoverLocalEngine.build(
        entries: loadedEntries,
        baselineThemes: baselineMap,
      );
      final growth = await ArchiveGrowthService.load();
      beliefs = ArchiveBeliefsPresenter.build(
        entries: loadedEntries,
        archiveV1: growth.archiveV1,
        discoverFeed: feed,
      );
      changing = buildBeliefChangeTimeline(snapshot: beliefs, feed: feed);
      insights = ref
          .read(appServicesProvider)
          .archiveIntelligence
          .buildInsights(
            entries: loadedEntries,
            discoverFeed: feed,
            currentBelief: beliefs.current.isNotEmpty
                ? beliefs.current.first.statement
                : null,
          );
    }

    return ArchiveBootstrapSnapshot(
      isPro: isPro,
      proBridgeResolved:
          (resolved[1] as RecordReturnProState).proBridgeResolved,
      betaActivationLoopCounts: resolved[2] as BetaActivationLoopCounts,
      entries: loadedEntries,
      beliefs: beliefs,
      changing: changing,
      insights: insights,
    );
  }

  Future<ArchiveBootstrapSnapshot> _loadFocusedV1() async {
    final loadedEntries = await ref.read(journalServiceProvider).loadAll();
    ArchiveBeliefsSnapshot? beliefs;
    var changing = const <BeliefChangeTimelineItem>[];
    var insights = ArchiveInsightsSnapshot.empty;
    if (loadedEntries.length >= 2 &&
        !isIntentionalEmptyArchive(loadedEntries)) {
      final baselineRaw = await ref.read(prefsProvider).discoverBaseline;
      final baselineMap = baselineRaw?.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
      final feed = DiscoverLocalEngine.build(
        entries: loadedEntries,
        baselineThemes: baselineMap,
      );
      final growth = await ArchiveGrowthService.load();
      beliefs = ArchiveBeliefsPresenter.build(
        entries: loadedEntries,
        archiveV1: growth.archiveV1,
        discoverFeed: feed,
      );
      changing = buildBeliefChangeTimeline(snapshot: beliefs, feed: feed);
      insights = ref
          .read(appServicesProvider)
          .archiveIntelligence
          .buildInsights(
            entries: loadedEntries,
            discoverFeed: feed,
            currentBelief: beliefs.current.isNotEmpty
                ? beliefs.current.first.statement
                : null,
          );
    }
    return ArchiveBootstrapSnapshot(
      entries: loadedEntries,
      isPro: false,
      betaActivationLoopCounts: const BetaActivationLoopCounts(),
      proBridgeResolved: false,
      beliefs: beliefs,
      changing: changing,
      insights: insights,
    );
  }
}

final archiveEntryCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(archiveBootstrapProvider).value?.entries.length ?? 0,
);

class ArchiveSessionState {
  const ArchiveSessionState({
    this.retentionDismissed = false,
    this.dismissedWorkspaceHints = const {},
    this.revision = 0,
  });

  final bool retentionDismissed;
  final Set<String> dismissedWorkspaceHints;
  final int revision;

  ArchiveSessionState copyWith({
    bool? retentionDismissed,
    Set<String>? dismissedWorkspaceHints,
    int? revision,
  }) {
    return ArchiveSessionState(
      retentionDismissed: retentionDismissed ?? this.retentionDismissed,
      dismissedWorkspaceHints:
          dismissedWorkspaceHints ?? this.dismissedWorkspaceHints,
      revision: revision ?? this.revision,
    );
  }
}

final archiveSessionProvider =
    NotifierProvider.autoDispose<ArchiveSessionController, ArchiveSessionState>(
      ArchiveSessionController.new,
    );

class ArchiveSessionController extends Notifier<ArchiveSessionState> {
  @override
  ArchiveSessionState build() => const ArchiveSessionState();

  void dismissRetention() {
    state = state.copyWith(retentionDismissed: true);
  }

  void dismissWorkspaceHint(String hintId) {
    state = state.copyWith(
      dismissedWorkspaceHints: {...state.dismissedWorkspaceHints, hintId},
      revision: state.revision + 1,
    );
  }

  void refreshSurface() {
    state = state.copyWith(revision: state.revision + 1);
  }
}
