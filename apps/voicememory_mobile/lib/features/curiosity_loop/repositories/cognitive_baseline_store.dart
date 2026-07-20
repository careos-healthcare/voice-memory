import 'package:flutter/foundation.dart';

import '../../../services/app_services.dart';
import '../../../storage/encrypted_json_storage.dart';
import '../../../storage/mobile_prefs_store.dart';
import '../domain/models/cognitive_biomarkers.dart';

/// Persisted EWMA cognitive baseline snapshot.
class CognitiveBaselineSnapshot {
  CognitiveBaselineSnapshot({
    CognitiveBiomarkers? baseline,
    CognitiveBiomarkers? biomarkers,
    required this.updatedAt,
    this.lastEntryId = 'entry_1',
    this.observationCount = 1,
  }) : baseline = baseline ?? biomarkers! {
    assert(
      baseline != null || biomarkers != null,
      'Provide baseline or biomarkers.',
    );
  }

  final CognitiveBiomarkers baseline;
  final String lastEntryId;
  final DateTime updatedAt;
  final int observationCount;

  /// Alias for [baseline] used by export and presentation surfaces.
  CognitiveBiomarkers get biomarkers => baseline;

  /// Composite index aligned with [TelemetryDataPoint.recoveryIndex] chart scale.
  double get referenceRecoveryIndex =>
      baseline.lexicalDiversity - baseline.cohesionDrift;

  Map<String, dynamic> toJson() => {
        'baseline': baseline.toJson(),
        'lastEntryId': lastEntryId,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'observationCount': observationCount,
      };

  static CognitiveBaselineSnapshot? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final baseline = CognitiveBiomarkers.fromJson(map['baseline']);
    final lastEntryId = map['lastEntryId'] as String?;
    final updatedAt = DateTime.tryParse(map['updatedAt'] as String? ?? '');
    final observationCount = (map['observationCount'] as num?)?.toInt();
    if (baseline == null ||
        lastEntryId == null ||
        lastEntryId.trim().isEmpty ||
        updatedAt == null ||
        observationCount == null ||
        observationCount < 1) {
      return null;
    }
    return CognitiveBaselineSnapshot(
      baseline: baseline,
      lastEntryId: lastEntryId.trim(),
      updatedAt: updatedAt.toUtc(),
      observationCount: observationCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CognitiveBaselineSnapshot &&
            other.baseline == baseline &&
            other.lastEntryId == lastEntryId &&
            other.updatedAt == updatedAt &&
            other.observationCount == observationCount;
  }

  @override
  int get hashCode =>
      Object.hash(baseline, lastEntryId, updatedAt, observationCount);
}

/// Persistence boundary for macro cognitive EWMA baselines.
abstract interface class CognitiveBaselineStore {
  Future<CognitiveBaselineSnapshot?> loadSnapshot();

  Future<bool> saveSnapshot(CognitiveBaselineSnapshot snapshot);
}

class LocalCognitiveBaselineStore implements CognitiveBaselineStore {
  LocalCognitiveBaselineStore({
    required MobilePrefsStore prefs,
    required EncryptedJsonStorage cryptoStorage,
  })  : _prefs = prefs,
        _cryptoStorage = cryptoStorage;

  static const prefsKey = 'secure_cognitive_baseline_snapshot';
  static const legacyPrefsKey = 'cognitiveBaselineState_v1';

  final MobilePrefsStore _prefs;
  final EncryptedJsonStorage _cryptoStorage;

  CognitiveBaselineSnapshot? _cached;

  static LocalCognitiveBaselineStore instance() => LocalCognitiveBaselineStore(
        prefs: AppServices.instance.prefs,
        cryptoStorage: AppServices.instance.clinicalTelemetryEncryptedStorage,
      );

  static LocalCognitiveBaselineStore forPrefs(
    MobilePrefsStore prefs, {
    EncryptedJsonStorage? cryptoStorage,
    List<int>? masterKeyBytes,
  }) =>
      LocalCognitiveBaselineStore(
        prefs: prefs,
        cryptoStorage: cryptoStorage ??
            EncryptedJsonStorage(
              masterKeyBytes: masterKeyBytes ??
                  (throw ArgumentError(
                    'Provide cryptoStorage or masterKeyBytes.',
                  )),
            ),
      );

  @override
  Future<bool> saveSnapshot(CognitiveBaselineSnapshot snapshot) async {
    try {
      final encryptedBoxString =
          await _cryptoStorage.encryptData(snapshot.toJson());
      await _prefs.writeString(prefsKey, encryptedBoxString);
      _cached = snapshot;
      return true;
    } catch (e) {
      debugPrint(
        '[Security Warning] Failed to securely write baseline payload: $e',
      );
      return false;
    }
  }

  @override
  Future<CognitiveBaselineSnapshot?> loadSnapshot() async {
    if (_cached != null) return _cached;

    for (final key in [prefsKey, legacyPrefsKey]) {
      final encryptedData = await _prefs.readString(key);
      if (encryptedData != null && encryptedData.trim().isNotEmpty) {
        final decryptedMap = await _cryptoStorage.decryptData(encryptedData);
        if (decryptedMap != null) {
          final snapshot = CognitiveBaselineSnapshot.fromJson(decryptedMap);
          if (snapshot != null) {
            if (key != prefsKey) {
              _cached = snapshot;
              await saveSnapshot(snapshot);
              await _prefs.writeString(legacyPrefsKey, '');
            } else {
              _cached = snapshot;
            }
            return _cached;
          }
        }

        if (key == prefsKey) {
          debugPrint(
            '[Security Warning] Baseline decryption integrity failed. '
            'Clearing compromised key.',
          );
          await _prefs.writeString(prefsKey, '');
          _cached = null;
          return null;
        }
      }

      final legacy = await _prefs.readJsonMap(key);
      if (legacy != null && legacy.isNotEmpty) {
        final snapshot = CognitiveBaselineSnapshot.fromJson(legacy);
        if (snapshot != null) {
          _cached = snapshot;
          if (key != prefsKey) {
            await saveSnapshot(snapshot);
            await _prefs.writeJsonMap(legacyPrefsKey, {});
          }
          return _cached;
        }
      }
    }

    return null;
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    if (prefs == null) return;
    await prefs.writeString(prefsKey, '');
    await prefs.writeJsonMap(legacyPrefsKey, {});
  }
}
