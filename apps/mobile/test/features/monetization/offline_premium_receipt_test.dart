import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    PremiumAccess.apply(PremiumEntitlement.free);
  });

  test('a cached premium receipt keeps Obsidian and vector search offline', () {
    PremiumAccess.apply(PremiumEntitlement.active);
    PremiumAccess.apply(PremiumEntitlement.free);
    OfflinePremiumReceipt.cached = PremiumEntitlement.active;

    expect(
      FreeTierGate.allowsObsidianSync(
        PremiumEntitlement.free,
        offline: true,
      ),
      isTrue,
    );
    expect(
      FreeTierGate.allowsLocalVectorSearch(
        PremiumEntitlement.free,
        offline: true,
      ),
      isTrue,
    );
    expect(
      FreeTierGate.allowsObsidianSync(
        PremiumEntitlement.free,
        offline: false,
      ),
      isFalse,
    );
  });

  test('offline without a cached receipt does not grant premium', () {
    OfflinePremiumReceipt.cached = null;
    expect(
      FreeTierGate.allowsLocalVectorSearch(
        PremiumEntitlement.free,
        offline: true,
      ),
      isFalse,
    );
  });
}
