import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'dart:io';

void main() {
  late Directory temp;
  late MobilePrefsStore prefs;
  late ValueMomentPaywallLogic logic;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('vm_paywall_');
    prefs = await MobilePrefsStore.open('${temp.path}/prefs.json');
    logic = ValueMomentPaywallLogic(prefs);
  });

  test('first blind spot visit does not show paywall', () async {
    await logic.markFirstBlindSpotSeen();
    expect(
      await logic.shouldShowPostBlindSpot(
        reflectionCount: 5,
        entitlements: PremiumEntitlements.free(),
      ),
      isFalse,
    );
  });

  test('second visit at 5+ may show paywall', () async {
    await logic.recordBlindSpotsVisit();
    await logic.markFirstBlindSpotSeen();
    await logic.recordBlindSpotsVisit();
    expect(
      await logic.shouldShowPostBlindSpot(
        reflectionCount: 5,
        entitlements: PremiumEntitlements.free(),
      ),
      isTrue,
    );
  });

  test('pro bypass', () async {
    await logic.recordBlindSpotsVisit();
    await logic.recordBlindSpotsVisit();
    expect(
      logic.shouldBypass(PremiumEntitlements.fromJson({
        'tier': 'pro',
        'entitlements': [],
        'billingConnected': true,
        'source': 'paid',
      })),
      isTrue,
    );
  });

  test('under 5 reflections never post blind spot paywall', () async {
    await logic.recordBlindSpotsVisit();
    await logic.markFirstBlindSpotSeen();
    await logic.recordBlindSpotsVisit();
    expect(
      await logic.shouldShowPostBlindSpot(
        reflectionCount: 4,
        entitlements: PremiumEntitlements.free(),
      ),
      isFalse,
    );
  });
}
