import 'package:flutter/foundation.dart';

import '../../../services/app_services.dart';
import '../../../storage/encrypted_json_storage.dart';
import '../../../storage/mobile_prefs_store.dart';
import '../domain/services/cognitive_trajectory_evaluator.dart';
import '../presentation/models/telemetry_data_point.dart';

/// Persisted hook-response trajectory record for longitudinal charts.
class StoredTrajectoryRecord {
  const StoredTrajectoryRecord({
    required this.date,
    required this.directionValue,
    required this.lexicalDelta,
    required this.driftDelta,
    required this.wasGrounded,
    this.entryId,
    this.hookId,
    this.volatilityDelta,
  });

  final DateTime date;
  final String directionValue;
  final double lexicalDelta;
  final double driftDelta;

  /// Captures if sensory down-regulation was active.
  final bool wasGrounded;

  /// Optional correlation ids retained for hook-response auditing.
  final String? entryId;
  final String? hookId;
  final double? volatilityDelta;

  /// Alias used by chart and export surfaces.
  DateTime get recordedAt => date;

  CognitiveDirection? get direction =>
      CognitiveDirection.values.asNameMap()[directionValue];

  TrajectoryAssessment? get assessment {
    final resolvedDirection = direction;
    final resolvedVolatility = volatilityDelta;
    if (resolvedDirection == null || resolvedVolatility == null) {
      return null;
    }
    return TrajectoryAssessment(
      lexicalDelta: lexicalDelta,
      driftDelta: driftDelta,
      volatilityDelta: resolvedVolatility,
      direction: resolvedDirection,
    );
  }

  factory StoredTrajectoryRecord.fromAssessment({
    required DateTime date,
    required String entryId,
    required String hookId,
    required TrajectoryAssessment assessment,
    bool wasGrounded = false,
  }) {
    return StoredTrajectoryRecord(
      date: date.toUtc(),
      directionValue: assessment.direction.name,
      lexicalDelta: assessment.lexicalDelta,
      driftDelta: assessment.driftDelta,
      wasGrounded: wasGrounded,
      entryId: entryId,
      hookId: hookId,
      volatilityDelta: assessment.volatilityDelta,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toUtc().toIso8601String(),
    'direction': directionValue,
    'lexicalDelta': lexicalDelta,
    'driftDelta': driftDelta,
    'wasGrounded': wasGrounded,
    if (entryId != null) 'entryId': entryId,
    if (hookId != null) 'hookId': hookId,
    if (volatilityDelta != null) 'volatilityDelta': volatilityDelta,
  };

  factory StoredTrajectoryRecord.fromJsonMap(Map<String, dynamic> json) {
    final dateRaw = json['date'] ?? json['recordedAt'];
    return StoredTrajectoryRecord(
      date: DateTime.parse(dateRaw as String).toUtc(),
      directionValue: json['direction'] as String,
      lexicalDelta: _parseScore(json['lexicalDelta'])!,
      driftDelta: _parseScore(json['driftDelta'])!,
      wasGrounded: json['wasGrounded'] as bool? ?? false,
      entryId: json['entryId'] as String?,
      hookId: json['hookId'] as String?,
      volatilityDelta: _parseScore(json['volatilityDelta']),
    );
  }

  static StoredTrajectoryRecord? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final dateRaw = map['date'] ?? map['recordedAt'];
    final directionValue = map['direction'] as String?;
    final lexicalDelta = _parseScore(map['lexicalDelta']);
    final driftDelta = _parseScore(map['driftDelta']);
    if (dateRaw is! String ||
        DateTime.tryParse(dateRaw) == null ||
        directionValue == null ||
        lexicalDelta == null ||
        driftDelta == null) {
      return null;
    }

    try {
      return StoredTrajectoryRecord.fromJsonMap(map);
    } catch (_) {
      return null;
    }
  }

  TelemetryDataPoint toTelemetryDataPoint() {
    return TelemetryDataPoint(
      date: date,
      direction: direction ?? CognitiveDirection.stagnant,
      lexicalDelta: lexicalDelta,
      driftDelta: driftDelta,
      wasGrounded: wasGrounded,
    );
  }

  static double? _parseScore(dynamic raw) {
    if (raw is! num) return null;
    final value = raw.toDouble();
    if (value.isNaN || value.isInfinite) return null;
    return value;
  }
}

/// Persistence boundary for clinical trajectory chart history.
abstract interface class ClinicalTrajectoryHistoryStore {
  Future<bool> appendRecord(StoredTrajectoryRecord record);

  Future<List<TelemetryDataPoint>> loadRecent({
    Duration window = const Duration(days: 7),
    DateTime? now,
  });
}

class LocalClinicalTrajectoryHistoryStore
    implements ClinicalTrajectoryHistoryStore {
  LocalClinicalTrajectoryHistoryStore({
    required this._prefs,
    required this._cryptoStorage,
  });

  static const prefsKey = 'secure_clinical_trajectory_history_records';
  static const legacyPrefsKey = 'clinicalTrajectoryHistory_v1';
  static const maxRecords = 120;
  static const maxDays = 90;
  static const retention = Duration(days: maxDays);

  final MobilePrefsStore _prefs;
  final EncryptedJsonStorage _cryptoStorage;

  List<StoredTrajectoryRecord> _cached = const [];

  static LocalClinicalTrajectoryHistoryStore instance() =>
      LocalClinicalTrajectoryHistoryStore(
        prefs: AppServices.instance.prefs,
        cryptoStorage: AppServices.instance.clinicalTelemetryEncryptedStorage,
      );

  static LocalClinicalTrajectoryHistoryStore forPrefs(
    MobilePrefsStore prefs, {
    EncryptedJsonStorage? cryptoStorage,
    List<int>? masterKeyBytes,
  }) => LocalClinicalTrajectoryHistoryStore(
    prefs: prefs,
    cryptoStorage:
        cryptoStorage ??
        EncryptedJsonStorage(
          masterKeyBytes:
              masterKeyBytes ??
              (throw ArgumentError('Provide cryptoStorage or masterKeyBytes.')),
        ),
  );

  @override
  Future<bool> appendRecord(StoredTrajectoryRecord record) async {
    try {
      final records = [...await _loadRecords(), record]
        ..sort((a, b) => a.date.compareTo(b.date));
      final pruned = _prune(records, anchor: record.date);
      await _persist(pruned);
      return true;
    } catch (e) {
      debugPrint(
        '[Security Warning] System failed to securely cycle data telemetry '
        'log fields: $e',
      );
      return false;
    }
  }

  @override
  Future<List<TelemetryDataPoint>> loadRecent({
    Duration window = const Duration(days: 7),
    DateTime? now,
  }) async {
    final anchor = (now ?? DateTime.now()).toUtc();
    final cutoff = anchor.subtract(window);
    final records = await _loadRecords();
    return records
        .where((record) => !record.date.isBefore(cutoff))
        .map((record) => record.toTelemetryDataPoint())
        .toList();
  }

  Future<List<StoredTrajectoryRecord>> _loadRecords() async {
    if (_cached.isNotEmpty) return _cached;

    for (final key in [prefsKey, legacyPrefsKey]) {
      final encryptedData = await _prefs.readString(key);
      if (encryptedData != null && encryptedData.trim().isNotEmpty) {
        final decryptedMap = await _cryptoStorage.decryptData(encryptedData);
        if (decryptedMap != null) {
          final records = _recordsFromPayload(decryptedMap);
          if (key != prefsKey) {
            await _persist(records);
            await _prefs.writeString(legacyPrefsKey, '');
          }
          return records;
        }

        if (key == prefsKey) {
          debugPrint(
            '[Security Warning] Trajectory tracking data failed authenticity '
            'tag checking.',
          );
          await _prefs.writeString(prefsKey, '');
          _cached = const [];
          return const [];
        }
      }

      final legacy = await _prefs.readJsonMap(key);
      if (legacy != null && legacy.isNotEmpty) {
        final records = _recordsFromPayload(legacy);
        if (key != prefsKey) {
          await _persist(records);
          await _prefs.writeJsonMap(legacyPrefsKey, {});
        } else {
          _cached = records;
        }
        return records;
      }
    }

    return const [];
  }

  List<StoredTrajectoryRecord> _recordsFromPayload(
    Map<String, dynamic> payload,
  ) {
    final rawList = payload['records'];
    if (rawList is! List) {
      _cached = const [];
      return const [];
    }

    try {
      _cached =
          rawList
              .map(StoredTrajectoryRecord.fromJson)
              .whereType<StoredTrajectoryRecord>()
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      _cached = _prune(_cached, anchor: DateTime.now().toUtc());
      return _cached;
    } catch (e) {
      debugPrint(
        'Parsing error evaluating decrypted trajectory structures: $e',
      );
      return const [];
    }
  }

  Future<void> _persist(List<StoredTrajectoryRecord> records) async {
    final encryptedBoxString = await _cryptoStorage.encryptData({
      'records': records.map((item) => item.toJson()).toList(),
    });
    await _prefs.writeString(prefsKey, encryptedBoxString);
    _cached = records;
  }

  List<StoredTrajectoryRecord> _prune(
    List<StoredTrajectoryRecord> records, {
    required DateTime anchor,
  }) {
    final retentionCutoff = anchor.toUtc().subtract(retention);
    final retained = records
        .where((record) => !record.date.isBefore(retentionCutoff))
        .toList();
    if (retained.length <= maxRecords) return retained;
    return retained.sublist(retained.length - maxRecords);
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    if (prefs == null) return;
    await prefs.writeString(prefsKey, '');
    await prefs.writeJsonMap(legacyPrefsKey, {});
  }
}
