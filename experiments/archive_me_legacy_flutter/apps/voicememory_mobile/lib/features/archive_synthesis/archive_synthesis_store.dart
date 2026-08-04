import '../../storage/mobile_prefs_store.dart';
import 'archive_synthesis_models.dart';

/// Local cache for all GPT synthesis outputs (deterministic archive unchanged).
class ArchiveSynthesisStore {
  ArchiveSynthesisStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _monthlyKey = 'archiveMonthlyReviews';
  static const _milestoneKey = 'archiveMilestoneReviews';
  static const _deepDiveKey = 'archiveDeepDiveNarratives';
  static const _historianKey = 'archiveHistorianReports';
  static const _metaKey = 'archiveSynthesisMeta';

  Future<ArchiveMonthlyReview?> readMonthly({required String cacheKey}) async {
    final raw = await _prefs.readJsonMap(_monthlyKey);
    if (raw == null) return null;
    final entry = raw[cacheKey];
    if (entry is! Map) return null;
    return ArchiveMonthlyReview.fromJson(Map<String, dynamic>.from(entry));
  }

  Future<void> writeMonthly({
    required String cacheKey,
    required ArchiveMonthlyReview review,
  }) async {
    final raw = await _prefs.readJsonMap(_monthlyKey) ?? {};
    raw[cacheKey] = review.toJson();
    await _prefs.writeJsonMap(_monthlyKey, raw);
  }

  /// Permanent storage keyed by milestone threshold only.
  Future<ArchiveMilestoneReview?> readMilestone(int threshold) async {
    final raw = await _prefs.readJsonMap(_milestoneKey);
    if (raw == null) return null;
    final entry = raw['$threshold'];
    if (entry is! Map) return null;
    return ArchiveMilestoneReview.fromJson(Map<String, dynamic>.from(entry));
  }

  Future<void> writeMilestone(ArchiveMilestoneReview review) async {
    final raw = await _prefs.readJsonMap(_milestoneKey) ?? {};
    raw['${review.milestoneThreshold}'] = review.toJson();
    await _prefs.writeJsonMap(_milestoneKey, raw);
  }

  Future<ArchiveDeepDiveNarrative?> readDeepDive(String cacheKey) async {
    final raw = await _prefs.readJsonMap(_deepDiveKey);
    if (raw == null) return null;
    final entry = raw[cacheKey];
    if (entry is! Map) return null;
    return ArchiveDeepDiveNarrative.fromJson(Map<String, dynamic>.from(entry));
  }

  Future<void> writeDeepDive({
    required String cacheKey,
    required ArchiveDeepDiveNarrative narrative,
  }) async {
    final raw = await _prefs.readJsonMap(_deepDiveKey) ?? {};
    raw[cacheKey] = {
      'beliefStatement': narrative.beliefStatement,
      'archiveHash': narrative.archiveHash,
      'generatedAt': narrative.generatedAt.toUtc().toIso8601String(),
      'model': narrative.model,
      'narrativeExplanation': narrative.narrativeExplanation,
      'evidenceSynthesis': narrative.evidenceSynthesis
          .map(ArchiveMonthlyReview.conclusionToJson)
          .toList(),
      'beliefEvolutionSummary': ArchiveMonthlyReview.conclusionToJson(
        narrative.beliefEvolutionSummary,
      ),
      'uncertaintyNote': narrative.uncertaintyNote,
      'reviewVersion': 4,
    };
    await _prefs.writeJsonMap(_deepDiveKey, raw);
  }

  Future<ArchiveHistorianReport?> readHistorian({
    required String cacheKey,
  }) async {
    final raw = await _prefs.readJsonMap(_historianKey);
    if (raw == null) return null;
    final entry = raw[cacheKey];
    if (entry is! Map) return null;
    return ArchiveHistorianReport.fromJson(Map<String, dynamic>.from(entry));
  }

  Future<void> writeHistorian({
    required String cacheKey,
    required ArchiveHistorianReport report,
  }) async {
    final raw = await _prefs.readJsonMap(_historianKey) ?? {};
    raw[cacheKey] = {
      'reviewVersion': 4,
      'monthKey': report.monthKey,
      'archiveHash': report.archiveHash,
      'eligibleCount': report.eligibleCount,
      'generatedAt': report.generatedAt.toUtc().toIso8601String(),
      'model': report.model,
      'title': report.title,
      'timeline': report.timeline
          .map(ArchiveMonthlyReview.conclusionToJson)
          .toList(),
      'uncertaintyNote': report.uncertaintyNote,
    };
    await _prefs.writeJsonMap(_historianKey, raw);
  }

  Future<ArchiveSynthesisMeta> readMeta() async {
    final raw = await _prefs.readJsonMap(_metaKey);
    if (raw == null) return const ArchiveSynthesisMeta();
    final milestones = raw['celebratedMilestones'];
    return ArchiveSynthesisMeta(
      lastReviewMonthKey: raw['lastReviewMonthKey']?.toString(),
      celebratedMilestones: milestones is List
          ? milestones.map((e) => (e as num).toInt()).toSet()
          : {},
      lastArchiveHash: raw['lastArchiveHash']?.toString(),
      lastHistorianMonthKey: raw['lastHistorianMonthKey']?.toString(),
    );
  }

  Future<void> writeMeta(ArchiveSynthesisMeta meta) async {
    await _prefs.writeJsonMap(_metaKey, {
      if (meta.lastReviewMonthKey != null)
        'lastReviewMonthKey': meta.lastReviewMonthKey,
      'celebratedMilestones': meta.celebratedMilestones.toList()..sort(),
      if (meta.lastArchiveHash != null) 'lastArchiveHash': meta.lastArchiveHash,
      if (meta.lastHistorianMonthKey != null)
        'lastHistorianMonthKey': meta.lastHistorianMonthKey,
    });
  }
}

class ArchiveSynthesisMeta {
  const ArchiveSynthesisMeta({
    this.lastReviewMonthKey,
    this.celebratedMilestones = const {},
    this.lastArchiveHash,
    this.lastHistorianMonthKey,
  });

  final String? lastReviewMonthKey;
  final Set<int> celebratedMilestones;
  final String? lastArchiveHash;
  final String? lastHistorianMonthKey;
}
