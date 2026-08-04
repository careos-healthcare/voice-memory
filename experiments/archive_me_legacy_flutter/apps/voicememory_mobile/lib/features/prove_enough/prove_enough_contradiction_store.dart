import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../loop_mode/loop_mode_model.dart';
import '../signal_review/signal_review_model.dart';
import 'prove_enough_contradiction_model.dart';

/// Local contradiction captures that can challenge prove_enough review evidence.
class ProveEnoughContradictionStore {
  ProveEnoughContradictionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'proveEnoughContradictions';

  static ProveEnoughContradictionStore instance() =>
      ProveEnoughContradictionStore(AppServices.instance.prefs);

  static ProveEnoughContradictionStore forPrefs(MobilePrefsStore prefs) =>
      ProveEnoughContradictionStore(prefs);

  Future<List<ProveEnoughContradictionRecord>> loadAll() async {
    final raw = await _prefs.readMap(_key);
    final items = raw?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map(
          (e) => ProveEnoughContradictionRecord.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .whereType<ProveEnoughContradictionRecord>()
        .toList();
  }

  Future<List<ProveEnoughContradictionRecord>> loadForJourney(
    String journeyId,
  ) async {
    final all = await loadAll();
    return all.where((row) => row.journeyId == journeyId).toList();
  }

  Future<List<String>> labelsForJourney(String journeyId) async {
    final rows = await loadForJourney(journeyId);
    return rows.map((row) => row.label).toList();
  }

  Future<ProveEnoughContradictionRecord> save({
    required ProveEnoughContradictionOption option,
    String? journeyId,
    String? entryId,
    DateTime? now,
  }) async {
    final record = ProveEnoughContradictionRecord(
      id: 'pec_${DateTime.now().microsecondsSinceEpoch}',
      option: option,
      savedAt: now ?? DateTime.now(),
      journeyId: journeyId,
      entryId: entryId,
    );

    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      final items = map['items'];
      final list = items is List
          ? List<Map<String, dynamic>>.from(items)
          : <Map<String, dynamic>>[];
      list.add(record.toJson());
      map['items'] = list;
      return map;
    });

    return record;
  }

  /// Adds saved contradiction labels to prove_enough review challenge copy.
  Future<SignalReview> enrichReviewChallengeEvidence(
    SignalReview review,
  ) async {
    if (review.loopModeId != LoopModeIds.proveEnough) return review;

    final labels = await labelsForJourney(review.journeyId);
    if (labels.isEmpty) return review;

    final base =
        (review.whatWouldProveThisWrong ?? review.possibleContradictions)
            .trim();
    final merged = <String>[];
    if (base.isNotEmpty) merged.add(base);
    for (final label in labels) {
      final line = 'Captured: $label';
      if (!merged.any((existing) => existing.contains(label))) {
        merged.add(line);
      }
    }

    return review.copyWith(
      whatWouldProveThisWrong: merged.join('\n'),
      possibleContradictions: merged.join('\n'),
    );
  }
}
