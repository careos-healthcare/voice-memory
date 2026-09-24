import 'dart:io';

import 'package:archiveme_mobile/core/user/advanced_search_settings.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson clamps out-of-range knobs', () {
    final settings = AdvancedSearchSettings.fromJson({
      'rrfK': 4,
      'candidateLimit': 400,
      'ragChunkLimit': 1,
    });

    expect(settings.rrfK, AdvancedSearchSettings.rrfKMin);
    expect(settings.candidateLimit, AdvancedSearchSettings.candidateLimitMax);
    expect(settings.ragChunkLimit, AdvancedSearchSettings.ragChunkLimitMin);
  });

  test('store round-trips persisted knobs', () async {
    final dir = Directory.systemTemp.createTempSync('vm_search_settings_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final store = AdvancedSearchSettingsStore(prefs);

    await store.save(
      const AdvancedSearchSettings(
        rrfK: 80,
        candidateLimit: 40,
        ragChunkLimit: 10,
      ),
    );

    final loaded = await store.load();
    expect(loaded.rrfK, 80);
    expect(loaded.candidateLimit, 40);
    expect(loaded.ragChunkLimit, 10);
  });
}
