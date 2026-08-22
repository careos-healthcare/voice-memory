import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(DeveloperSettingsGate.resetForTest);

  test(
    'registerVersionTap unlocks after seven taps when gate is closed',
    () async {
      DeveloperSettingsGate.resetForTest();
      if (DeveloperSettingsGate.canShowDeveloperSettings) {
        final noop = await DeveloperSettingsGate.registerVersionTap(
          persistUnlock: () async {},
        );
        expect(noop, isFalse);
        return;
      }

      var persistCalls = 0;
      for (var i = 0; i < 6; i++) {
        final unlocked = await DeveloperSettingsGate.registerVersionTap(
          persistUnlock: () async {
            persistCalls += 1;
          },
        );
        expect(unlocked, isFalse);
      }

      final unlocked = await DeveloperSettingsGate.registerVersionTap(
        persistUnlock: () async {
          persistCalls += 1;
        },
      );

      expect(unlocked, isTrue);
      expect(persistCalls, 1);
      expect(DeveloperSettingsGate.unlockedViaGesture, isTrue);
      expect(DeveloperSettingsGate.canShowDeveloperSettings, isTrue);
    },
  );

  test('loadFromPrefs restores unlock state', () {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.loadFromPrefs(true);
    expect(DeveloperSettingsGate.canShowDeveloperSettings, isTrue);
  });
}