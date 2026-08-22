import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Pending memory-recall configuration for the next curiosity hook.
class CuriosityMemoryRecallSeed {
  const CuriosityMemoryRecallSeed({
    required this.sourceEntryId,
    required this.seededAt,
  });

  final String sourceEntryId;
  final DateTime seededAt;

  Map<String, dynamic> toJson() => {
    'sourceEntryId': sourceEntryId,
    'seededAt': seededAt.toUtc().toIso8601String(),
  };

  static CuriosityMemoryRecallSeed? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final sourceEntryId = map['sourceEntryId'] as String?;
    final seededAt = DateTime.tryParse(map['seededAt'] as String? ?? '');
    if (sourceEntryId == null ||
        sourceEntryId.trim().isEmpty ||
        seededAt == null) {
      return null;
    }
    return CuriosityMemoryRecallSeed(
      sourceEntryId: sourceEntryId.trim(),
      seededAt: seededAt.toUtc(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CuriosityMemoryRecallSeed &&
            other.sourceEntryId == sourceEntryId &&
            other.seededAt == seededAt;
  }

  @override
  int get hashCode => Object.hash(sourceEntryId, seededAt);
}

/// Curiosity loop state boundary for clinical save side-effects.
abstract interface class CuriosityLoopRepository {
  Future<void> seedMemoryRecallCheck({
    required String sourceEntryId,
    required DateTime seededAt,
  });

  Future<CuriosityMemoryRecallSeed?> fetchPendingMemoryRecallSeed();

  Future<void> clearPendingMemoryRecallSeed();
}

class LocalCuriosityLoopRepository implements CuriosityLoopRepository {
  LocalCuriosityLoopRepository(this._prefs);

  static const prefsKey = 'curiosityLoopState_v1';

  final MobilePrefsStore _prefs;

  static CuriosityMemoryRecallSeed? _cachedSeed;

  static LocalCuriosityLoopRepository instance() =>
      LocalCuriosityLoopRepository(AppServices.instance.prefs);

  static LocalCuriosityLoopRepository forPrefs(MobilePrefsStore prefs) =>
      LocalCuriosityLoopRepository(prefs);

  @override
  Future<void> seedMemoryRecallCheck({
    required String sourceEntryId,
    required DateTime seededAt,
  }) async {
    final trimmed = sourceEntryId.trim();
    if (trimmed.isEmpty) return;

    final seed = CuriosityMemoryRecallSeed(
      sourceEntryId: trimmed,
      seededAt: seededAt.toUtc(),
    );
    await _prefs.writeJsonMap(prefsKey, {'pendingMemoryRecall': seed.toJson()});
    _cachedSeed = seed;
  }

  @override
  Future<CuriosityMemoryRecallSeed?> fetchPendingMemoryRecallSeed() async {
    if (_cachedSeed != null) return _cachedSeed;

    final raw = await _prefs.readJsonMap(prefsKey);
    final seed = CuriosityMemoryRecallSeed.fromJson(
      raw?['pendingMemoryRecall'],
    );
    _cachedSeed = seed;
    return seed;
  }

  @override
  Future<void> clearPendingMemoryRecallSeed() async {
    _cachedSeed = null;
    await _prefs.writeJsonMap(prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _cachedSeed = null;
    if (prefs == null) return;
    await prefs.writeJsonMap(prefsKey, {});
  }
}