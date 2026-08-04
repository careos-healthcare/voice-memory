import 'dart:async';

import '../../storage/encrypted_json_file_store.dart';
import 'sandbox_models.dart';

final class SandboxAuditRecord {
  SandboxAuditRecord({
    required this.id,
    required this.moduleId,
    required this.status,
    required DateTime occurredAt,
    required this.elapsedMicroseconds,
    required this.peakMemoryBytes,
    required this.fuelConsumed,
    required this.grants,
    this.reason,
  }) : occurredAt = occurredAt.toUtc();

  final String id;
  final String moduleId;
  final SandboxJobStatus status;
  final DateTime occurredAt;
  final int elapsedMicroseconds;
  final int peakMemoryBytes;
  final int fuelConsumed;
  final List<SandboxDataGrant> grants;
  final String? reason;

  Map<String, Object?> toJson() => {
    'id': id,
    'moduleId': moduleId,
    'status': status.name,
    'occurredAt': occurredAt.toIso8601String(),
    'elapsedMicroseconds': elapsedMicroseconds,
    'peakMemoryBytes': peakMemoryBytes,
    'fuelConsumed': fuelConsumed,
    'grants': grants.map((grant) => grant.name).toList(),
    'reason': reason,
  };

  factory SandboxAuditRecord.fromJson(Map<String, Object?> json) =>
      SandboxAuditRecord(
        id: json['id']! as String,
        moduleId: json['moduleId']! as String,
        status: SandboxJobStatus.values.byName(json['status']! as String),
        occurredAt: DateTime.parse(json['occurredAt']! as String),
        elapsedMicroseconds:
            (json['elapsedMicroseconds'] as num?)?.toInt() ?? 0,
        peakMemoryBytes: (json['peakMemoryBytes'] as num?)?.toInt() ?? 0,
        fuelConsumed: (json['fuelConsumed'] as num?)?.toInt() ?? 0,
        grants: (json['grants'] as List? ?? const [])
            .whereType<String>()
            .map(SandboxDataGrant.values.byName)
            .toList(),
        reason: json['reason'] as String?,
      );
}

final class SandboxAuditStore {
  SandboxAuditStore(this.storage);

  final EncryptedJsonFileStore storage;
  Future<void> _tail = Future.value();
  static const maximumRecords = 100;

  Future<List<SandboxAuditRecord>> read() => _serialized(_read);

  Future<List<SandboxAuditRecord>> _read() async {
    try {
      final value = await storage.readJson();
      if (value is! Map || value['schemaVersion'] != 1) return const [];
      return (value['records'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                SandboxAuditRecord.fromJson(Map<String, Object?>.from(item)),
          )
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> append(SandboxAuditRecord record) async {
    await _serialized(() async {
      final current = await _read();
      final next = [...current, record];
      final bounded = next.skip(
        (next.length - maximumRecords).clamp(0, next.length),
      );
      await storage.writeJson({
        'schemaVersion': 1,
        'records': bounded.map((item) => item.toJson()).toList(),
      });
    });
  }

  Future<void> clear() => _serialized(() => storage.writeJson(const {}));

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> dispose() => _tail.catchError((_) {});
}
