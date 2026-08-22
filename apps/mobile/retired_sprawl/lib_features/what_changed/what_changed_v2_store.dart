import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local-only What Changed v2 markers keyed by entry id.
class WhatChangedV2Store {
  WhatChangedV2Store(this._prefs);

  static const _prefsKey = 'what_changed_v2_records_v1';

  final MobilePrefsStore _prefs;

  static List<WhatChangedV2Record> _cached = const [];
  static bool _loaded = false;

  static WhatChangedV2Store instance() =>
      WhatChangedV2Store(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  static List<WhatChangedV2Record> get cached => _cached;

  Future<List<WhatChangedV2Record>> loadAll() async {
    final raw = await _prefs.readJsonMap(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) =>
              WhatChangedV2Record.fromJson(Map<String, dynamic>.from(entry)),
        )
        .where((record) => record.entryId.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  WhatChangedV2Record? recordForEntry(String entryId) {
    for (final record in _cached) {
      if (record.entryId == entryId) return record;
    }
    return null;
  }

  Future<void> save(WhatChangedV2Record record) async {
    final records = [
      record,
      ..._cached.where((existing) => existing.entryId != record.entryId),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cached = records;
    _loaded = true;
    await _prefs.writeJsonMap(_prefsKey, {
      'records': records.map((item) => item.toJson()).toList(),
    });
  }

  Future<void> saveSelection({
    required String entryId,
    required WhatChangedV2Option option,
    required int entryCountAtCapture,
    RepeatReturnCheckStore? returnCheckStore,
  }) async {
    final record = WhatChangedV2Record(
      entryId: entryId,
      option: option,
      entryCountAtCapture: entryCountAtCapture,
      createdAt: DateTime.now().toUtc(),
    );
    final records = [
      record,
      ..._cached.where((existing) => existing.entryId != record.entryId),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cached = records;
    _loaded = true;

    final repeatChoice = _repeatChoiceFor(option);
    final store = returnCheckStore ?? RepeatReturnCheckStore.instance();
    if (repeatChoice != null) {
      store.stageChoice(
        entryId: entryId,
        choice: repeatChoice,
        entryCountAtCapture: entryCountAtCapture,
      );
    }

    await _prefs.writeJsonMap(_prefsKey, {
      'records': records.map((item) => item.toJson()).toList(),
    });

    if (repeatChoice != null) {
      await store.saveChoice(
        entryId: entryId,
        choice: repeatChoice,
        entryCountAtCapture: entryCountAtCapture,
      );
    }
  }

  static RepeatReturnCheckChoice? _repeatChoiceFor(
    WhatChangedV2Option option,
  ) => switch (option) {
    WhatChangedV2Option.stronger => RepeatReturnCheckChoice.stronger,
    WhatChangedV2Option.softer => RepeatReturnCheckChoice.softer,
    WhatChangedV2Option.same => RepeatReturnCheckChoice.same,
    WhatChangedV2Option.differentResponse => RepeatReturnCheckChoice.changed,
    WhatChangedV2Option.somethingHelped => null,
  };

  static Future<void> clearAll() async {
    _cached = const [];
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(_prefsKey, {});
  }

  static void invalidateAfterRestore() => invalidateCache();

  @visibleForTesting
  static void invalidateCache() {
    _cached = const [];
    _loaded = false;
  }

  static Future<void> resetPersistedState() async {
    await clearAll();
  }

  @visibleForTesting
  static Future<void> resetForTest() => resetPersistedState();
}