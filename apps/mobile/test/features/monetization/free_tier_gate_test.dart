import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline does not grant premium or lock the free archive', () {
    for (final offline in [false, true]) {
      expect(FreeTierGate.allowsLocalArchive(offline: offline), isTrue);
      expect(FreeTierGate.allowsAudioCapture(offline: offline), isTrue);
      expect(
        FreeTierGate.allowsMeshOffload(
          PremiumEntitlement.free,
          offline: offline,
        ),
        isFalse,
      );
      expect(
        FreeTierGate.allowsMultiDeviceSync(
          PremiumEntitlement.free,
          offline: offline,
        ),
        isFalse,
      );
      expect(
        FreeTierGate.allowsDeeperCoaching(
          PremiumEntitlement.free,
          offline: offline,
        ),
        isFalse,
      );
      expect(
        FreeTierGate.allowsMeshOffload(
          PremiumEntitlement.active,
          offline: offline,
        ),
        isTrue,
      );
      expect(
        FreeTierGate.allowsDeeperCoaching(
          PremiumEntitlement.active,
          offline: offline,
        ),
        isTrue,
      );
    }
  });
}
