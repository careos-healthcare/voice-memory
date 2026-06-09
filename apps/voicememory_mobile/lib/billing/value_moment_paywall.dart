import '../product/consumer_ui_copy.dart';
import '../config/app_config.dart';
import '../models/entitlement.dart';
import '../storage/mobile_prefs_store.dart';

/// Value-moment paywall rules — mirrors web; no paywall before first value.
class ValueMomentPaywallLogic {
  ValueMomentPaywallLogic(this._prefs);

  final MobilePrefsStore _prefs;

  static const copyHeadline = ConsumerUiCopy.paywallHeadline;
  static const copyBody = ConsumerUiCopy.paywallSubhead;
  static const copyPatternMemory = ConsumerUiCopy.archivePatternOverTimeLine;
  static const ctaLabel = ConsumerUiCopy.paywallPrimaryCta;
  static const secondaryLabel = ConsumerUiCopy.paywallSecondaryCta;

  Future<Map<String, dynamic>> _state() => _prefs.valueMomentState();

  Future<void> _save(Map<String, dynamic> s) => _prefs.setValueMomentState(s);

  Future<void> markFirstBlindSpotSeen() async {
    final s = await _state();
    s['hasSeenFirstBlindSpot'] = true;
    await _save(s);
  }

  Future<void> markFirstDiscoverSeen() async {
    final s = await _state();
    s['hasSeenFirstDiscover'] = true;
    await _save(s);
  }

  Future<void> recordBlindSpotsVisit() async {
    final s = await _state();
    s['blindSpotsVisitCount'] = ((s['blindSpotsVisitCount'] as num?)?.toInt() ?? 0) + 1;
    await _save(s);
  }

  Future<void> recordDiscoverVisit() async {
    final s = await _state();
    s['discoverVisitCount'] = ((s['discoverVisitCount'] as num?)?.toInt() ?? 0) + 1;
    await _save(s);
  }

  Future<void> markPostBlindSpotSeen() async {
    final s = await _state();
    s['postBlindSpotPaywallSeen'] = true;
    await _save(s);
  }

  Future<void> markPostDiscoverSeen() async {
    final s = await _state();
    s['postDiscoverPaywallSeen'] = true;
    await _save(s);
  }

  bool shouldBypass(PremiumEntitlements? entitlements) {
    return entitlements?.isPro == true;
  }

  Future<bool> shouldShowPostBlindSpot({
    required int reflectionCount,
    required PremiumEntitlements? entitlements,
  }) async {
    if (shouldBypass(entitlements)) return false;
    if (reflectionCount < AppConfig.patternReviewReflectionTarget) return false;
    final s = await _state();
    if (s['hasSeenFirstBlindSpot'] != true) return false;
    if (s['postBlindSpotPaywallSeen'] == true) return false;
    final visits = (s['blindSpotsVisitCount'] as num?)?.toInt() ?? 0;
    return visits >= 2;
  }

  Future<bool> shouldShowPostDiscover({
    required PremiumEntitlements? entitlements,
  }) async {
    if (shouldBypass(entitlements)) return false;
    final s = await _state();
    if (s['hasSeenFirstDiscover'] != true) return false;
    if (s['postDiscoverPaywallSeen'] == true) return false;
    final visits = (s['discoverVisitCount'] as num?)?.toInt() ?? 0;
    return visits >= 2;
  }

  Future<bool> shouldGateContinuity({
    required PremiumEntitlements? entitlements,
  }) async {
    if (shouldBypass(entitlements)) return false;
    final s = await _state();
    return s['hasSeenFirstBlindSpot'] == true &&
        s['hasSeenFirstDiscover'] == true &&
        s['postBlindSpotPaywallSeen'] == true &&
        s['postDiscoverPaywallSeen'] == true;
  }
}
