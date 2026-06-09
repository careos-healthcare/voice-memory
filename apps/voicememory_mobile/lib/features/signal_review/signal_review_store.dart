import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'signal_review_model.dart';

/// Persists the active signal review and confirmed-review count for paywall.
class SignalReviewStore {
  SignalReviewStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _activeKey = 'signalReviewActive';
  static const _byJourneyKey = 'signalReviewByJourney';
  static const _confirmedCountKey = 'signalReviewConfirmedCount';
  static const _paywallTeaserDismissedKey = 'loopPaywallTeaserDismissed';

  static SignalReviewStore instance() =>
      SignalReviewStore(AppServices.instance.prefs);

  Future<SignalReview?> loadActive() async {
    final raw = await _prefs.readMap(_activeKey);
    return SignalReview.fromJson(raw);
  }

  Future<SignalReview?> loadForJourney(String journeyId) async {
    final raw = await _prefs.readMap(_byJourneyKey);
    if (raw == null) return null;
    final item = raw[journeyId];
    if (item is! Map) return null;
    return SignalReview.fromJson(
      item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item),
    );
  }

  Future<void> saveActive(SignalReview review) async {
    await _prefs.writeMap(_activeKey, review.toJson());
    final byJourney = await _prefs.readMap(_byJourneyKey) ?? {};
    byJourney[review.journeyId] = review.toJson();
    await _prefs.writeMap(_byJourneyKey, byJourney);
  }

  Future<void> clearActive() async {
    await _prefs.writeMap(_activeKey, {});
  }

  Future<int> confirmedReviewCount() async {
    final raw = await _prefs.readMap(_confirmedCountKey);
    return (raw?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> incrementConfirmedCount() async {
    final count = await confirmedReviewCount();
    await _prefs.writeMap(_confirmedCountKey, {'count': count + 1});
  }

  Future<bool> loopPaywallTeaserDismissed() async {
    final raw = await _prefs.readMap(_paywallTeaserDismissedKey);
    return raw?['dismissed'] == true;
  }

  Future<void> dismissLoopPaywallTeaser() async {
    await _prefs.writeMap(_paywallTeaserDismissedKey, {'dismissed': true});
  }
}
