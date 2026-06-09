import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_range_review_model.dart';

/// Persists the latest archive range review plus a capped history.
class ArchiveRangeReviewStore {
  ArchiveRangeReviewStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _latestKey = 'archiveRangeReviewLatest';
  static const _historyKey = 'archiveRangeReviewHistory';
  static const _historyMax = 20;

  static ArchiveRangeReviewStore instance() =>
      ArchiveRangeReviewStore(AppServices.instance.prefs);

  Future<ArchiveRangeReview?> loadLatest() async {
    final raw = await _prefs.readMap(_latestKey);
    return ArchiveRangeReview.fromJson(raw);
  }

  Future<void> saveLatest(ArchiveRangeReview review) async {
    await _prefs.writeMap(_latestKey, review.toJson());
  }

  Future<List<ArchiveRangeReview>> loadHistory({int limit = 20}) async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .map((e) => ArchiveRangeReview.fromJson(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ))
        .whereType<ArchiveRangeReview>()
        .take(limit)
        .toList();
  }

  Future<void> appendHistory(ArchiveRangeReview review) async {
    final history = await loadHistory(limit: _historyMax);
    final next = [
      review,
      ...history.where((h) => h.id != review.id),
    ].take(_historyMax).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((r) => r.toJson()).toList(),
    });
  }

  Future<void> clear() async {
    await _prefs.writeMap(_latestKey, {});
    await _prefs.writeMap(_historyKey, {'items': []});
  }
}
