import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/data/repositories/archive_synthesis_repository.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_gate.dart';
import 'package:archiveme_mobile/features/archive_deep_dive/archive_deep_dive_models.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_hash.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_models.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_pack_builder.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_pro_gate.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_store.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_trigger.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/device_id.dart';

/// GPT-5 synthesis V2 — parallel layer; does not modify archive engines.
class ArchiveSynthesisService {
  ArchiveSynthesisService({
    required this._store,
    required this._repository,
    required this._deviceIds,
  });

  final ArchiveSynthesisStore _store;
  final ArchiveSynthesisRepository _repository;
  final DeviceIdStore _deviceIds;

  Future<ArchiveSynthesisLoadResult> loadMonthly({
    required ArchiveV1View view,
    required PremiumEntitlements entitlements,
    String? userId,
  }) async {
    if (!AppConfig.enableGpt5ArchiveSynthesis) {
      return const ArchiveSynthesisLoadResult.disabled();
    }
    if (!ArchiveSynthesisProGate.canAccessArchiveIntelligence(entitlements)) {
      return const ArchiveSynthesisLoadResult.requiresPro();
    }

    final eligible = ArchiveAnalystGate.eligibleCount(view.eligibleEntries);
    if (eligible < ArchiveSynthesisTrigger.minEligible) {
      return ArchiveSynthesisLoadResult.belowThreshold(eligible);
    }

    final monthKey = ArchiveSynthesisTrigger.monthKeyFor(DateTime.now());
    final meta = await _store.readMeta();
    final milestones = _milestonesReached(eligible);
    final archiveHash = ArchiveSynthesisPackBuilder.hashForView(
      view: view,
      monthKey: monthKey,
      milestonesReached: milestones,
    );

    final subjectId = await _subjectId(userId);
    final cacheKey = synthesisCacheKey(
      userId: subjectId,
      monthKey: monthKey,
      archiveHash: archiveHash,
    );

    final cached = await _store.readMonthly(cacheKey: cacheKey);
    if (cached != null) {
      return ArchiveSynthesisLoadResult.ready(review: cached, fromCache: true);
    }

    final shouldFetch = ArchiveSynthesisTrigger.shouldRequestSynthesis(
      eligibleCount: eligible,
      monthKey: monthKey,
      lastReviewMonthKey: meta.lastReviewMonthKey,
      celebratedMilestones: meta.celebratedMilestones,
      cachedArchiveHash: meta.lastArchiveHash,
      currentArchiveHash: archiveHash,
    );

    if (!shouldFetch) {
      return const ArchiveSynthesisLoadResult.notDue();
    }

    if (!AppConfig.isBackendConfigured) {
      return const ArchiveSynthesisLoadResult.backendUnavailable();
    }

    final pack = ArchiveSynthesisPackBuilder.build(
      view: view,
      monthKey: monthKey,
      milestonesReached: milestones,
    );

    final responseResult = await _repository.postArchiveSynthesis(
      synthesisType: ArchiveSynthesisType.monthly,
      monthKey: monthKey,
      userId: subjectId,
      pack: pack,
    );
    final response = responseResult.when(
      success: (value) => value,
      onFailure: (_) => null,
    );

    final review = response?.monthlyReview;
    if (review == null) {
      return const ArchiveSynthesisLoadResult.fetchFailed();
    }

    await _store.writeMonthly(cacheKey: cacheKey, review: review);
    await _store.writeMeta(
      ArchiveSynthesisMeta(
        lastReviewMonthKey: monthKey,
        celebratedMilestones: {...meta.celebratedMilestones, ...milestones},
        lastArchiveHash: archiveHash,
        lastHistorianMonthKey: meta.lastHistorianMonthKey,
      ),
    );

    return ArchiveSynthesisLoadResult.ready(review: review, fromCache: false);
  }

  /// Permanent milestone reviews — fetch once per threshold.
  Future<List<ArchiveMilestoneReview>> loadMilestoneReviews({
    required ArchiveV1View view,
    required PremiumEntitlements entitlements,
    String? userId,
  }) async {
    if (!AppConfig.enableGpt5ArchiveSynthesis) return const [];
    if (!ArchiveSynthesisProGate.canAccessArchiveIntelligence(entitlements)) {
      return const [];
    }
    final eligible = ArchiveAnalystGate.eligibleCount(view.eligibleEntries);
    if (eligible < ArchiveSynthesisTrigger.minEligible) return const [];

    final monthKey = ArchiveSynthesisTrigger.monthKeyFor(DateTime.now());
    final milestones = _milestonesReached(eligible);
    final subjectId = await _subjectId(userId);
    final out = <ArchiveMilestoneReview>[];

    for (final threshold in ArchiveSynthesisTrigger.milestones) {
      if (eligible < threshold) continue;

      final stored = await _store.readMilestone(threshold);
      if (stored != null) {
        out.add(stored);
        continue;
      }

      if (!AppConfig.isBackendConfigured) continue;

      final pack = ArchiveSynthesisPackBuilder.build(
        view: view,
        monthKey: monthKey,
        milestonesReached: milestones,
      );

      final responseResult = await _repository.postArchiveSynthesis(
        synthesisType: ArchiveSynthesisType.milestone,
        monthKey: monthKey,
        userId: subjectId,
        pack: pack,
        milestoneThreshold: threshold,
      );
      final response = responseResult.when(
        success: (value) => value,
        onFailure: (_) => null,
      );

      final review = response?.milestoneReview;
      if (review != null) {
        await _store.writeMilestone(review);
        out.add(review);
        final meta = await _store.readMeta();
        await _store.writeMeta(
          ArchiveSynthesisMeta(
            lastReviewMonthKey: meta.lastReviewMonthKey,
            celebratedMilestones: {...meta.celebratedMilestones, threshold},
            lastArchiveHash: meta.lastArchiveHash,
            lastHistorianMonthKey: meta.lastHistorianMonthKey,
          ),
        );
      }
    }

    out.sort((a, b) => a.milestoneThreshold.compareTo(b.milestoneThreshold));
    return out;
  }

  Future<ArchiveHistorianLoadResult> loadHistorian({
    required ArchiveV1View view,
    required PremiumEntitlements entitlements,
    String? userId,
  }) async {
    if (!AppConfig.enableGpt5ArchiveSynthesis) {
      return const ArchiveHistorianLoadResult.disabled();
    }
    if (!ArchiveSynthesisProGate.canAccessArchiveIntelligence(entitlements)) {
      return const ArchiveHistorianLoadResult.requiresPro();
    }

    final eligible = ArchiveAnalystGate.eligibleCount(view.eligibleEntries);
    if (eligible < ArchiveSynthesisTrigger.minEligible) {
      return ArchiveHistorianLoadResult.belowThreshold(eligible);
    }

    final monthKey = ArchiveSynthesisTrigger.monthKeyFor(DateTime.now());
    final meta = await _store.readMeta();
    final milestones = _milestonesReached(eligible);
    final archiveHash = ArchiveSynthesisPackBuilder.hashForView(
      view: view,
      monthKey: monthKey,
      milestonesReached: milestones,
    );

    final subjectId = await _subjectId(userId);
    final cacheKey = 'historian:$subjectId:$monthKey:$archiveHash';

    final cached = await _store.readHistorian(cacheKey: cacheKey);
    if (cached != null) {
      return ArchiveHistorianLoadResult.ready(report: cached, fromCache: true);
    }

    final historianDue =
        meta.lastHistorianMonthKey != monthKey ||
        meta.lastArchiveHash != archiveHash;

    if (!historianDue) {
      return const ArchiveHistorianLoadResult.notDue();
    }

    if (!AppConfig.isBackendConfigured) {
      return const ArchiveHistorianLoadResult.backendUnavailable();
    }

    final pack = ArchiveSynthesisPackBuilder.build(
      view: view,
      monthKey: monthKey,
      milestonesReached: milestones,
    );

    final responseResult = await _repository.postArchiveSynthesis(
      synthesisType: ArchiveSynthesisType.historian,
      monthKey: monthKey,
      userId: subjectId,
      pack: pack,
    );
    final response = responseResult.when(
      success: (value) => value,
      onFailure: (_) => null,
    );

    final report = response?.historianReport;
    if (report == null) {
      return const ArchiveHistorianLoadResult.fetchFailed();
    }

    await _store.writeHistorian(cacheKey: cacheKey, report: report);
    await _store.writeMeta(
      ArchiveSynthesisMeta(
        lastReviewMonthKey: meta.lastReviewMonthKey,
        celebratedMilestones: meta.celebratedMilestones,
        lastArchiveHash: archiveHash,
        lastHistorianMonthKey: monthKey,
      ),
    );

    return ArchiveHistorianLoadResult.ready(report: report, fromCache: false);
  }

  Future<ArchiveDeepDiveNarrativeLoadResult> loadDeepDiveNarrative({
    required ArchiveV1View view,
    required ArchiveDeepDiveView dive,
    required PremiumEntitlements entitlements,
    String? userId,
  }) async {
    if (!AppConfig.enableGpt5ArchiveSynthesis) {
      return const ArchiveDeepDiveNarrativeLoadResult.disabled();
    }
    if (!ArchiveSynthesisProGate.canAccessArchiveIntelligence(entitlements)) {
      return const ArchiveDeepDiveNarrativeLoadResult.requiresPro();
    }

    final eligible = ArchiveAnalystGate.eligibleCount(view.eligibleEntries);
    if (eligible < ArchiveSynthesisTrigger.minEligible) {
      return ArchiveDeepDiveNarrativeLoadResult.belowThreshold();
    }

    final monthKey = ArchiveSynthesisTrigger.monthKeyFor(DateTime.now());
    final milestones = _milestonesReached(eligible);
    final pack = ArchiveSynthesisPackBuilder.buildWithDeepDiveContext(
      view: view,
      monthKey: monthKey,
      milestonesReached: milestones,
      dive: dive,
    );
    final archiveHash = computeArchiveHashFromPack(pack);
    final subjectId = await _subjectId(userId);
    final cacheKey = 'deep_dive:$subjectId:$archiveHash';

    final cached = await _store.readDeepDive(cacheKey);
    if (cached != null) {
      return ArchiveDeepDiveNarrativeLoadResult.ready(
        narrative: cached,
        fromCache: true,
      );
    }

    if (!AppConfig.isBackendConfigured) {
      return const ArchiveDeepDiveNarrativeLoadResult.backendUnavailable();
    }

    final responseResult = await _repository.postArchiveSynthesis(
      synthesisType: ArchiveSynthesisType.deepDive,
      monthKey: monthKey,
      userId: subjectId,
      pack: pack,
    );
    final response = responseResult.when(
      success: (value) => value,
      onFailure: (_) => null,
    );

    final narrative = response?.deepDiveNarrative;
    if (narrative == null) {
      return const ArchiveDeepDiveNarrativeLoadResult.fetchFailed();
    }

    await _store.writeDeepDive(cacheKey: cacheKey, narrative: narrative);
    return ArchiveDeepDiveNarrativeLoadResult.ready(
      narrative: narrative,
      fromCache: false,
    );
  }

  Future<String> _subjectId(String? userId) async =>
      userId ?? await _deviceIds.getOrCreate();
}

Set<int> _milestonesReached(int eligible) {
  final out = <int>{};
  for (final m in ArchiveSynthesisTrigger.milestones) {
    if (eligible >= m) out.add(m);
  }
  return out;
}

class ArchiveSynthesisLoadResult {
  const ArchiveSynthesisLoadResult._({
    required this.status,
    this.review,
    this.fromCache = false,
    this.eligibleCount,
  });

  const ArchiveSynthesisLoadResult.disabled()
    : this._(status: ArchiveSynthesisStatus.disabled);

  const ArchiveSynthesisLoadResult.notDue()
    : this._(status: ArchiveSynthesisStatus.notDue);

  const ArchiveSynthesisLoadResult.belowThreshold(int count)
    : this._(
        status: ArchiveSynthesisStatus.belowThreshold,
        eligibleCount: count,
      );

  const ArchiveSynthesisLoadResult.backendUnavailable()
    : this._(status: ArchiveSynthesisStatus.backendUnavailable);

  const ArchiveSynthesisLoadResult.fetchFailed()
    : this._(status: ArchiveSynthesisStatus.fetchFailed);

  const ArchiveSynthesisLoadResult.requiresPro()
    : this._(status: ArchiveSynthesisStatus.requiresPro);

  const ArchiveSynthesisLoadResult.ready({
    required ArchiveMonthlyReview review,
    required bool fromCache,
  }) : this._(
         status: ArchiveSynthesisStatus.ready,
         review: review,
         fromCache: fromCache,
       );

  final ArchiveSynthesisStatus status;
  final ArchiveMonthlyReview? review;
  final bool fromCache;
  final int? eligibleCount;

  bool get showSection =>
      status == ArchiveSynthesisStatus.ready && review != null;
}

enum ArchiveSynthesisStatus {
  disabled,
  requiresPro,
  notDue,
  belowThreshold,
  backendUnavailable,
  fetchFailed,
  ready,
}

class ArchiveHistorianLoadResult {
  const ArchiveHistorianLoadResult._({
    required this.status,
    this.report,
    this.fromCache = false,
    this.eligibleCount,
  });

  const ArchiveHistorianLoadResult.disabled()
    : this._(status: ArchiveHistorianStatus.disabled);
  const ArchiveHistorianLoadResult.notDue()
    : this._(status: ArchiveHistorianStatus.notDue);
  const ArchiveHistorianLoadResult.belowThreshold(int count)
    : this._(
        status: ArchiveHistorianStatus.belowThreshold,
        eligibleCount: count,
      );
  const ArchiveHistorianLoadResult.backendUnavailable()
    : this._(status: ArchiveHistorianStatus.backendUnavailable);
  const ArchiveHistorianLoadResult.fetchFailed()
    : this._(status: ArchiveHistorianStatus.fetchFailed);
  const ArchiveHistorianLoadResult.requiresPro()
    : this._(status: ArchiveHistorianStatus.requiresPro);
  const ArchiveHistorianLoadResult.ready({
    required ArchiveHistorianReport report,
    required bool fromCache,
  }) : this._(
         status: ArchiveHistorianStatus.ready,
         report: report,
         fromCache: fromCache,
       );

  final ArchiveHistorianStatus status;
  final ArchiveHistorianReport? report;
  final bool fromCache;
  final int? eligibleCount;

  bool get showSection =>
      status == ArchiveHistorianStatus.ready && report != null;
}

enum ArchiveHistorianStatus {
  disabled,
  requiresPro,
  notDue,
  belowThreshold,
  backendUnavailable,
  fetchFailed,
  ready,
}

class ArchiveDeepDiveNarrativeLoadResult {
  const ArchiveDeepDiveNarrativeLoadResult._({
    required this.status,
    this.narrative,
    this.fromCache = false,
  });

  const ArchiveDeepDiveNarrativeLoadResult.disabled()
    : this._(status: ArchiveDeepDiveNarrativeStatus.disabled);
  const ArchiveDeepDiveNarrativeLoadResult.belowThreshold()
    : this._(status: ArchiveDeepDiveNarrativeStatus.belowThreshold);
  const ArchiveDeepDiveNarrativeLoadResult.backendUnavailable()
    : this._(status: ArchiveDeepDiveNarrativeStatus.backendUnavailable);
  const ArchiveDeepDiveNarrativeLoadResult.fetchFailed()
    : this._(status: ArchiveDeepDiveNarrativeStatus.fetchFailed);
  const ArchiveDeepDiveNarrativeLoadResult.requiresPro()
    : this._(status: ArchiveDeepDiveNarrativeStatus.requiresPro);
  const ArchiveDeepDiveNarrativeLoadResult.ready({
    required ArchiveDeepDiveNarrative narrative,
    required bool fromCache,
  }) : this._(
         status: ArchiveDeepDiveNarrativeStatus.ready,
         narrative: narrative,
         fromCache: fromCache,
       );

  final ArchiveDeepDiveNarrativeStatus status;
  final ArchiveDeepDiveNarrative? narrative;
  final bool fromCache;

  bool get showSection =>
      status == ArchiveDeepDiveNarrativeStatus.ready && narrative != null;
}

enum ArchiveDeepDiveNarrativeStatus {
  disabled,
  requiresPro,
  belowThreshold,
  backendUnavailable,
  fetchFailed,
  ready,
}