import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'monthly_pattern_review_model.dart';

/// Persists the latest monthly recap in its own prefs key so the rest of the
/// schema is untouched.
class MonthlyPatternReviewStore {
  MonthlyPatternReviewStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'monthlyPatternReview';

  static MonthlyPatternReviewStore instance() =>
      MonthlyPatternReviewStore(AppServices.instance.prefs);

  Future<void> save(MonthlyPatternReview review) async {
    await _prefs.writeMap(_key, review.toJson());
  }

  Future<MonthlyPatternReview?> load() async {
    final raw = await _prefs.readMap(_key);
    return MonthlyPatternReview.fromJson(raw);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }
}
