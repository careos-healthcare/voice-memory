import 'dart:io';

import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/core/user/life_stage_lens_prompt.dart';
import 'package:archiveme_mobile/core/user/user_settings.dart';
import 'package:archiveme_mobile/core/user/user_settings_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserSettings round-trips thematic lens', () {
    const settings = UserSettings(activeLens: LifeStageLens.griefLoss);
    final json = settings.toJson();
    expect(json['activeLens'], 'griefLoss');

    final restored = UserSettings.fromJson(json);
    expect(restored.activeLens, LifeStageLens.griefLoss);
  });

  test('default lens omits wire value from json', () {
    const settings = UserSettings(activeLens: LifeStageLens.defaultLens);
    expect(settings.toJson(), isEmpty);
  });

  test('LifeStageLensPrompt returns block for thematic lenses only', () {
    expect(LifeStageLensPrompt.systemBlockFor(LifeStageLens.defaultLens), isNull);
    expect(
      LifeStageLensPrompt.systemBlockFor(LifeStageLens.careerTransition),
      contains('CAREER TRANSITION LENS'),
    );
  });

  test('UserSettingsStore persists active lens', () async {
    final dir = await Directory.systemTemp.createTemp('life_stage_lens_test');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final store = UserSettingsStore(prefs);

    await store.setActiveLens(LifeStageLens.recovery);
    final loaded = await store.load();

    expect(loaded.activeLens, LifeStageLens.recovery);
  });
}