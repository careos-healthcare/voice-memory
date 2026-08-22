import 'dart:convert';

import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:archiveme_mobile/sync/sync_backoff_policy.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:drift/drift.dart';

/// Lifecycle state for a row in the drift-backed sync outbox.
enum SyncOutboxStatus {
  pending('pending'),
  inFlight('in_flight'),
  sent('sent'),
  failed('failed');

  const SyncOutboxStatus(this.storageValue);
  final String storageValue;

  static SyncOutboxStatus parse(String? raw) {
    return SyncOutboxStatus.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => SyncOutboxStatus.pending,
    );
  }
}

/// One locally persisted [SyncBlobPushDto] awaiting encrypted cloud push.
class SyncOutboxEntry {
  const SyncOutboxEntry({
    required this.outboxId,
    required this.blob,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
    this.nextRetryAt,
  });

  final String outboxId;
  final SyncBlobPushDto blob;
  final SyncOutboxStatus status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;
  final DateTime? nextRetryAt;
}

/// Drift-backed outbox — SQLite is the authoritative queue for sync pushes.
class SyncOutboxStore {
  SyncOutboxStore(
    this._db, {
    SyncBackoffPolicy backoff = const SyncBackoffPolicy(),
  }) : _backoff = backoff;

  final JournalDatabase _db;
  final SyncBackoffPolicy _backoff;

  /// Persists [blob] locally before any network push (coalesces pending rows
  /// for the same `blob.id` + `blob.type` from macOS or mobile).
  Future<String> enqueue(SyncBlobPushDto blob) async {
    final now = DateTime.now().toUtc();
    final nowMillis = now.millisecondsSinceEpoch;
    final payloadJson = jsonEncode(blob.toJson());

    final existing = await (_db.select(_db.syncOutboxEntries)
          ..where(
            (row) =>
                row.blobId.equals(blob.id) &
                row.blobType.equals(blob.type) &
                row.status.isIn([
                  SyncOutboxStatus.pending.storageValue,
                  SyncOutboxStatus.inFlight.storageValue,
                ]),
          )
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.syncOutboxEntries)
            ..where((row) => row.outboxId.equals(existing.outboxId)))
          .write(
        SyncOutboxEntriesCompanion(
          payloadJson: Value(payloadJson),
          status: Value(SyncOutboxStatus.pending.storageValue),
          updatedAt: Value(nowMillis),
          lastError: const Value(null),
          nextRetryAt: const Value(null),
        ),
      );
      return existing.outboxId;
    }

    final outboxId = generateUlid();
    await _db.into(_db.syncOutboxEntries).insert(
      SyncOutboxEntriesCompanion.insert(
        outboxId: outboxId,
        blobId: blob.id,
        blobType: blob.type,
        payloadJson: payloadJson,
        status: SyncOutboxStatus.pending.storageValue,
        attemptCount: 0,
        createdAt: nowMillis,
        updatedAt: nowMillis,
      ),
    );
    return outboxId;
  }

  Future<List<SyncOutboxEntry>> pending({int limit = 32}) async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rows = await (_db.select(_db.syncOutboxEntries)
          ..where(
            (row) =>
                row.status.equals(SyncOutboxStatus.pending.storageValue) &
                (row.nextRetryAt.isNull() |
                    row.nextRetryAt.isSmallerOrEqualValue(nowMillis)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_mapRow).toList(growable: false);
  }

  Future<int> pendingCount() async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final count = _db.syncOutboxEntries.outboxId.count();
    final query = _db.selectOnly(_db.syncOutboxEntries)
      ..addColumns([count])
      ..where(
        _db.syncOutboxEntries.status.equals(
              SyncOutboxStatus.pending.storageValue,
            ) &
            (_db.syncOutboxEntries.nextRetryAt.isNull() |
                _db.syncOutboxEntries.nextRetryAt.isSmallerOrEqualValue(
                  nowMillis,
                )),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Earliest scheduled retry across pending rows, if any are backing off.
  Future<DateTime?> nextReadyAt() async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final query = _db.selectOnly(_db.syncOutboxEntries)
      ..addColumns([_db.syncOutboxEntries.nextRetryAt.min()])
      ..where(
        _db.syncOutboxEntries.status.equals(
              SyncOutboxStatus.pending.storageValue,
            ) &
            _db.syncOutboxEntries.nextRetryAt.isBiggerThanValue(nowMillis),
      );
    final row = await query.getSingleOrNull();
    final millis = row?.read(_db.syncOutboxEntries.nextRetryAt.min());
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> markInFlight(String outboxId) async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final row = await (_db.select(_db.syncOutboxEntries)
          ..where((entry) => entry.outboxId.equals(outboxId)))
        .getSingleOrNull();
    if (row == null) return;

    await (_db.update(_db.syncOutboxEntries)
          ..where((entry) => entry.outboxId.equals(outboxId)))
        .write(
      SyncOutboxEntriesCompanion(
        status: Value(SyncOutboxStatus.inFlight.storageValue),
        updatedAt: Value(nowMillis),
        attemptCount: Value(row.attemptCount + 1),
      ),
    );
  }

  Future<void> markSent(String outboxId) async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.syncOutboxEntries)
          ..where((row) => row.outboxId.equals(outboxId)))
        .write(
      SyncOutboxEntriesCompanion(
        status: Value(SyncOutboxStatus.sent.storageValue),
        updatedAt: Value(nowMillis),
        lastError: const Value(null),
        nextRetryAt: const Value(null),
      ),
    );
  }

  Future<void> markFailed(String outboxId, String error) async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final row = await (_db.select(_db.syncOutboxEntries)
          ..where((entry) => entry.outboxId.equals(outboxId)))
        .getSingleOrNull();
    if (row == null) return;

    final attemptCount = row.attemptCount;
    if (!_backoff.hasAttemptsRemaining(attemptCount)) {
      await (_db.update(_db.syncOutboxEntries)
            ..where((entry) => entry.outboxId.equals(outboxId)))
          .write(
        SyncOutboxEntriesCompanion(
          status: Value(SyncOutboxStatus.failed.storageValue),
          updatedAt: Value(nowMillis),
          lastError: Value(error),
          nextRetryAt: const Value(null),
        ),
      );
      return;
    }

    final retryAt = _backoff.scheduleAfterAttempt(attemptCount).millisecondsSinceEpoch;
    await (_db.update(_db.syncOutboxEntries)
          ..where((entry) => entry.outboxId.equals(outboxId)))
        .write(
      SyncOutboxEntriesCompanion(
        status: Value(SyncOutboxStatus.pending.storageValue),
        updatedAt: Value(nowMillis),
        lastError: Value(error),
        nextRetryAt: Value(retryAt),
      ),
    );
  }

  /// Returns orphaned in-flight rows to pending (e.g. after process restart).
  Future<int> requeueInFlight() async {
    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    return _db.customUpdate(
      '''
      UPDATE sync_outbox
      SET status = ?, updated_at = ?, next_retry_at = NULL
      WHERE status = ?
      ''',
      variables: [
        Variable<String>(SyncOutboxStatus.pending.storageValue),
        Variable<int>(nowMillis),
        Variable<String>(SyncOutboxStatus.inFlight.storageValue),
      ],
      updates: {_db.syncOutboxEntries},
    );
  }

  SyncOutboxEntry _mapRow(SyncOutboxRow row) {
    final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    return SyncOutboxEntry(
      outboxId: row.outboxId,
      blob: SyncBlobPushDto.fromJson(payload),
      status: SyncOutboxStatus.parse(row.status),
      attemptCount: row.attemptCount,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
      lastError: row.lastError,
      nextRetryAt: row.nextRetryAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.nextRetryAt!, isUtc: true),
    );
  }
}
