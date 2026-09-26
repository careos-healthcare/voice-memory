import 'dart:async';
import 'dart:convert';

import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/data/network/http_sync_api_client.dart';
import 'package:archiveme_mobile/features/insights/knowledge_forget_service.dart';
import 'package:archiveme_mobile/features/settings/e2ee_sync_settings.dart';
import 'package:archiveme_mobile/features/sync/plain_text_ledger_consent.dart';
import 'package:archiveme_mobile/features/sync/services/account_sync_key.dart';
import 'package:archiveme_mobile/features/sync/services/attachment_sync_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/sync/e2ee_journal_sync.dart';
import 'package:archiveme_mobile/sync/record_sync.dart';

/// Sends journal text to the plain-text ledger after opt-in and a signed
/// plain-text AI processing consent. Encrypted sync stays on [E2eeSyncLifecycle].
class CloudSyncService {
  CloudSyncService({
    Future<void> Function(String entryId, String transcript, DateTime createdAt)?
    upload,
    Future<void> Function(String entryId, String transcript, DateTime createdAt)?
    update,
    Future<void> Function(String entryId)? remove,
    Future<void> Function(List<JournalEntry> chunk)? postChunk,
    Future<int> Function()? readCursor,
    Future<void> Function(int cursor)? writeCursor,
    Future<bool> Function()? isLedgerOptInEnabled,
    Future<bool> Function()? plainTextAiConsentSigned,
    Future<List<JournalEntry>> Function()? loadEntries,
    Future<Set<String>> Function()? forgottenLabels,
  }) : _upload = upload ?? _postToApi,
       _update = update ?? _putToApi,
       _remove = remove ?? _deleteOnApi,
       _postChunk = postChunk ?? _postBulkChunk,
       _readCursor = readCursor ?? _readBackfillCursor,
       _writeCursor = writeCursor ?? _writeBackfillCursor,
       _isLedgerOptInEnabled = isLedgerOptInEnabled ?? _readLedgerOptIn,
       _plainTextAiConsentSigned =
           plainTextAiConsentSigned ?? _readPlainTextConsent,
       _loadEntries = loadEntries ?? _readLocalEntries,
       _forgottenLabels = forgottenLabels ?? _readForgottenLabels;

  static const ingestPath = '/api/ledger/ingest';
  static const bulkImportPath = '/api/ledger/bulk-import';
  static const entryPath = '/api/ledger/entry';
  static const clearPath = '/api/ledger';
  static const backfillCursorKey = 'cloud_ledger_backfill_cursor';
  static const chunkSize = 20;

  final Future<void> Function(String entryId, String transcript, DateTime createdAt)
  _upload;
  final Future<void> Function(String entryId, String transcript, DateTime createdAt)
  _update;
  final Future<void> Function(String entryId) _remove;
  final Future<void> Function(List<JournalEntry> chunk) _postChunk;
  final Future<int> Function() _readCursor;
  final Future<void> Function(int cursor) _writeCursor;
  final Future<bool> Function() _isLedgerOptInEnabled;
  final Future<bool> Function() _plainTextAiConsentSigned;
  final Future<List<JournalEntry>> Function() _loadEntries;
  final Future<Set<String>> Function() _forgottenLabels;

  /// Posts one entry. Does nothing until ledger opt-in and consent both hold.
  /// Forgotten labels are left out of the copy sent to the server.
  Future<void> uploadEntryToLedger(JournalEntry entry) async {
    await _send(entry, _upload);
  }

  /// Replaces the server copy after a local edit.
  Future<void> updateEntryOnLedger(JournalEntry entry) async {
    await _send(entry, _update);
  }

  /// Removes one entry from the server ledger. The phone copy stays.
  Future<void> deleteEntryFromLedger(String entryId) async {
    if (!await _ledgerAllowed()) return;
    if (entryId.isEmpty) return;
    try {
      await _remove(entryId);
    } on Object {
      return;
    }
  }

  Future<void> _send(
    JournalEntry entry,
    Future<void> Function(String entryId, String transcript, DateTime createdAt)
    send,
  ) async {
    if (!await _ledgerAllowed()) return;
    if (entry.isDeleted) return;
    final transcript = omitForgottenLabels(
      entry.transcript.trim(),
      await _forgottenLabels(),
    );
    if (transcript.isEmpty) return;
    try {
      await send(entry.id, transcript, entry.createdAt);
    } on Object {
      return;
    }
  }

  /// Pushes every local journal entry once the plain-text ledger is allowed.
  static Future<void> backfillLocalEntries() {
    return CloudSyncService().backfill();
  }

  Future<void> backfill() async {
    if (!await _ledgerAllowed()) return;
    final entries = await _loadEntries();
    for (final entry in entries) {
      await uploadEntryToLedger(entry);
    }
  }

  /// Sends every local entry through `/api/ledger/bulk-import`, 20 at a time.
  ///
  /// The cursor is the number of entries already accepted. A failed chunk
  /// leaves the cursor in place so the next call continues.
  Future<void> backfillInChunks({
    void Function(int done, int total)? onProgress,
  }) async {
    if (!await _ledgerAllowed()) return;
    final entries = (await _loadEntries())
        .where((entry) => !entry.isDeleted && entry.transcript.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    var cursor = await _readCursor();
    if (cursor < 0 || cursor > entries.length) cursor = 0;
    onProgress?.call(cursor, entries.length);
    while (cursor < entries.length) {
      final end = cursor + chunkSize < entries.length
          ? cursor + chunkSize
          : entries.length;
      try {
        await _postChunk(entries.sublist(cursor, end));
      } on Object {
        return;
      }
      cursor = end;
      await _writeCursor(cursor);
      onProgress?.call(cursor, entries.length);
    }
  }

  static Future<void> _postToApi(
    String entryId,
    String transcript,
    DateTime createdAt,
  ) async {
    await _sendJson('POST', ingestPath, entryId, transcript, createdAt);
  }

  static Future<void> _putToApi(
    String entryId,
    String transcript,
    DateTime createdAt,
  ) async {
    await _sendJson('PUT', ingestPath, entryId, transcript, createdAt);
  }

  static Future<void> _sendJson(
    String method,
    String path,
    String entryId,
    String transcript,
    DateTime createdAt,
  ) async {
    if (!AppServices.isInitialized) return;
    final body = {
      'entryId': entryId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'transcript': transcript,
    };
    final transport = AppServices.instance.httpTransport;
    if (method == 'PUT') {
      await transport.put(path, body: body);
    } else {
      await transport.post(path, body: body);
    }
  }

  static Future<void> _deleteOnApi(String entryId) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.httpTransport.delete(
      entryPath,
      body: {'entryId': entryId},
    );
  }

  static Future<void> _postBulkChunk(List<JournalEntry> chunk) async {
    if (!AppServices.isInitialized || chunk.isEmpty) return;
    final forgotten = await _readForgottenLabels();
    await AppServices.instance.httpTransport.post(
      bulkImportPath,
      body: {
        'chunks': [
          for (final entry in chunk)
            {
              'entryId': entry.id,
              'rawText': omitForgottenLabels(entry.transcript.trim(), forgotten),
              'createdAt': entry.createdAt.toUtc().toIso8601String(),
            },
        ],
      },
    );
  }

  static Future<int> _readBackfillCursor() async {
    if (!AppServices.isInitialized) return 0;
    final raw = await AppServices.instance.prefs.readString(backfillCursorKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  static Future<void> _writeBackfillCursor(int cursor) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(
      backfillCursorKey,
      '$cursor',
    );
  }

  Future<bool> _ledgerAllowed() async {
    if (!await _isLedgerOptInEnabled()) return false;
    return _plainTextAiConsentSigned();
  }

  static Future<bool> _readLedgerOptIn() async {
    if (!V1CapabilityRegistry.isLedgerOptInEnabled) return false;
    if (!AppServices.isInitialized) return false;
    final preferences = await UserPreferences.load(AppServices.instance.prefs);
    return preferences.isLedgerOptInEnabled;
  }

  static Future<bool> _readPlainTextConsent() async {
    if (!AppServices.isInitialized) return false;
    return PlainTextLedgerConsent.isSigned(AppServices.instance.prefs);
  }

  static Future<List<JournalEntry>> _readLocalEntries() {
    if (!AppServices.isInitialized) return Future.value(const []);
    return AppServices.instance.journal.loadAll();
  }

  static Future<Set<String>> _readForgottenLabels() async {
    if (!AppServices.isInitialized) return {};
    return ForgottenKnowledge.load(AppServices.instance.prefs);
  }
}

/// Whether a foreground or debounced sync finished, was skipped, or failed.
enum E2eeSyncOutcome { skipped, synced, failed }

class E2eeSyncReport {
  const E2eeSyncReport._(this.outcome, this.reason);

  const E2eeSyncReport.skipped() : this._(E2eeSyncOutcome.skipped, null);

  const E2eeSyncReport.synced() : this._(E2eeSyncOutcome.synced, null);

  const E2eeSyncReport.failed(String reason)
    : this._(E2eeSyncOutcome.failed, reason);

  final E2eeSyncOutcome outcome;
  final String? reason;
}

/// Runs encrypted sync jobs one at a time so a resume cannot overlap a startup.
class E2eeSyncQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> enqueue<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then((_) {}, onError: (_, _) {});
    return result;
  }
}

/// Starts a delta sync when cloud features are on and a passphrase is stored.
abstract final class E2eeSyncLifecycle {
  E2eeSyncLifecycle._();

  static final queue = E2eeSyncQueue();

  static Future<E2eeSyncReport> syncIfEnabled() {
    return queue.enqueue(_syncIfEnabled);
  }

  static const lastSyncKey = 'last_sync_time';

  static Future<E2eeSyncReport> _syncIfEnabled() async {
    if (!V1CapabilityRegistry.e2eeSync) return const E2eeSyncReport.skipped();
    if (!AppServices.isInitialized) return const E2eeSyncReport.skipped();
    try {
      final preferences = await UserPreferences.load(
        AppServices.instance.prefs,
      );
      if (!preferences.isCloudSyncEnabled) {
        return const E2eeSyncReport.skipped();
      }
      final passphrase = await E2eeSyncSettings.storedPassphrase();
      if (passphrase == null || passphrase.trim().isEmpty) {
        return const E2eeSyncReport.skipped();
      }
      final accountKey = await _accountKeyFor(passphrase);
      if (accountKey == null) {
        return const E2eeSyncReport.failed(
          'The passphrase does not open this archive.',
        );
      }
      final deviceId = await AppServices.instance.deviceIds.getOrCreate();
      final lastRaw = await AppServices.instance.prefs.readString(lastSyncKey);
      final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
      await _applyRemote(accountKey: accountKey, since: last);
      final local = await AppServices.instance.journal.loadAll();
      final records = <SealedSyncRecord>[];
      for (final entry in local) {
        records.add(
          await RecordSync.sealEntry(
            accountKey: accountKey,
            recordId: entry.id,
            version: 1,
            deviceId: deviceId,
            state: E2eeJournalSync.fieldsFor(entry, deviceId),
          ),
        );
      }
      await _push(records);
      final syncedAt = DateTime.now().toUtc();
      await AppServices.instance.prefs.writeString(
        lastSyncKey,
        syncedAt.toIso8601String(),
      );
      final attachments = _attachmentSync(accountKey);
      for (final entry in local) {
        await attachments.uploadEntryAttachments(entry);
      }
      return const E2eeSyncReport.synced();
    } on Object catch (error) {
      final reason = error is StateError
          ? error.message
          : 'the archive did not accept this sync';
      return E2eeSyncReport.failed(reason);
    }
  }

  /// Fetches the account salt before deriving. A local wrap is used only when
  /// it already carries that salt, or when the server has not published one.
  static Future<List<int>?> _accountKeyFor(String passphrase) async {
    final remote = await AccountSyncKeyImport.loadParams();
    final local = await AccountSyncKey.readBundle();
    if (remote != null &&
        (local == null || local.wrappedByPassphrase.salt != remote.salt)) {
      try {
        final imported = await AccountSyncKeyImport.unlockWithParams(
          passphrase: passphrase,
          params: remote,
        );
        return imported.accountKey;
      } on AccountKeyUnlockFailed {
        return null;
      }
    }
    final wrapped = local?.wrappedByPassphrase;
    if (wrapped == null) return null;
    try {
      return await AccountSyncKey.unwrap(wrapped: wrapped, secret: passphrase);
    } on AccountKeyUnlockFailed {
      return null;
    }
  }

  static Future<void> _applyRemote({
    required List<int> accountKey,
    required DateTime? since,
  }) async {
    final local = await AppServices.instance.journal.loadAll();
    final client = HttpSyncApiClient(AppServices.instance.httpTransport);
    final result = await client.syncPull();
    final remote = result.when(
      success: (body) {
        final pull = SyncPullResponseDto.fromJson(body);
        return [
          for (final blob in pull.blobs)
            if (blob.type == SyncRecordKind.entry.name)
              if (DateTime.tryParse(blob.updatedAt) case final updated?)
                if (since == null || updated.isAfter(since))
                  SealedSyncRecord(
                    recordId: blob.id,
                    kind: SyncRecordKind.entry,
                    version: 1,
                    updatedAt: updated,
                    deviceId: '',
                    ciphertext: blob.encrypted.ciphertext,
                    nonce: blob.encrypted.iv,
                    keyVersion: RecordSync.keyVersion,
                  ),
        ];
      },
      onFailure: (_) => const <SealedSyncRecord>[],
    );
    final byId = {for (final entry in local) entry.id: entry};
    for (final record in remote) {
      final opened = await RecordSync.openEntry(
        accountKey: accountKey,
        record: record,
      );
      final current = byId[record.recordId];
      if (current != null && !record.updatedAt.isAfter(current.updatedAt)) {
        continue;
      }
      final next = (current ??
              JournalEntry(
                id: record.recordId,
                createdAt: record.updatedAt,
                transcript: '',
                durationSeconds: 0,
                reflection: const Reflection(
                  mood: '',
                  emotionalIntensity: 0,
                  recurringThemes: [],
                  exactLanguagePattern: '',
                  concreteObservation: '',
                  repeatedSignal: '',
                ),
              ))
          .copyWith(
            transcript: opened.transcript,
            updatedAt: record.updatedAt,
          );
      await AppServices.instance.journalStore.save(next);
    }
  }

  static Future<void> _push(List<SealedSyncRecord> records) async {
    if (records.isEmpty) return;
    final client = HttpSyncApiClient(AppServices.instance.httpTransport);
    final result = await client.syncPush(
      SyncPushRequestDto(
        blobs: [
          for (final record in records)
            SyncBlobPushDto(
              id: record.recordId,
              type: record.kind.name,
              encrypted: EncryptedPayloadDto(
                ciphertext: record.ciphertext,
                iv: record.nonce,
              ),
              updatedAt: record.updatedAt.toUtc().toIso8601String(),
              byteLength: record.ciphertext.length,
            ),
        ],
      ).toJson(),
    );
    final failed = result.when(success: (_) => false, onFailure: (_) => true);
    if (failed) throw StateError('Encrypted sync push did not succeed.');
  }

  static const attachmentSignPath = '/api/sync/attachments/sign';

  static AttachmentSyncService _attachmentSync(List<int> accountKey) {
    final transport = AppServices.instance.httpTransport;
    final service = AttachmentSyncService(
      accountKey: accountKey,
      sign:
          ({
            required String entryId,
            required String name,
            required String method,
          }) async {
            final result = await transport.post(
              attachmentSignPath,
              body: {'entryId': entryId, 'name': name, 'method': method},
            );
            return result.when(
              success: (response) {
                final decoded = jsonDecode(response.body);
                if (decoded is! Map) {
                  throw const FormatException(
                    'Signed attachment response was empty.',
                  );
                }
                final headers = <String, String>{};
                final raw = decoded['headers'];
                if (raw is Map) {
                  for (final entry in raw.entries) {
                    headers['${entry.key}'] = '${entry.value}';
                  }
                }
                return SignedObjectGrant(
                  url: Uri.parse(decoded['url'] as String),
                  headers: headers,
                );
              },
              onFailure: (_) => throw StateError(
                'Signed attachment request did not succeed.',
              ),
            );
          },
      putBytes: (grant, body) async {
        final response = await transport.client.put(
          grant.url,
          headers: {'Content-Type': 'application/octet-stream', ...grant.headers},
          body: body,
        );
        if (response.statusCode >= 400) {
          throw StateError('Attachment upload did not succeed.');
        }
      },
      getBytes: (grant) async {
        final response = await transport.client.get(
          grant.url,
          headers: grant.headers,
        );
        if (response.statusCode >= 400) {
          throw StateError('Attachment download did not succeed.');
        }
        return response.bodyBytes;
      },
    );
    AttachmentSyncService.active = service;
    return service;
  }
}
