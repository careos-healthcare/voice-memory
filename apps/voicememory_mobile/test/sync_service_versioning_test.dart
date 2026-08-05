// Objective 2 (real synchronization versioning and deletion) — covers
// SyncService.syncNow()'s tombstone push/pull, batching, and
// accept/reject handling against the server contract described in
// app/api/journal/route.ts and lib/server/journal-store.ts.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_fingerprints.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/journal_ownership_guard.dart';
import 'package:voicememory_mobile/services/sync_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

JournalEntry _newEntry({
  required String id,
  String transcript = 'hello',
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  transcript: transcript,
  durationSeconds: 5,
  reflection: _reflection(),
  syncStatus: SyncStatus.localOnly,
);

final _verifiedAt = DateTime.utc(2026, 6, 1);

VerifiedProof _fullVerifiedProof() {
  const statement = 'You check the numbers before deciding.';
  final evidence = [
    VerifiedEvidenceSnapshot(
      sourceEntryId: 'entry-meta-1',
      archiveScope: 'archive-1',
      ownerScope: 'owner-1',
      transcriptRevision: 'rev-1',
      transcriptFingerprint: 'fingerprint-1',
      sourceDate: _verifiedAt,
      sourceType: ProofSourceType.userTyped,
      quote: 'checked the numbers first',
      startUtf16: 0,
      endUtf16: 25,
      role: ProofEvidenceRole.support,
      verifiedAt: _verifiedAt,
    ),
  ];
  return VerifiedProof(
    proofId: 'proof-full-1',
    archiveScope: 'archive-1',
    ownerScope: 'owner-1',
    reflection: Reflection(
      mood: 'steady',
      emotionalIntensity: 3,
      recurringThemes: const [],
      exactLanguagePattern: 'checked the numbers first',
      concreteObservation: statement,
      repeatedSignal: '',
      patternObservations: const [],
    ),
    claims: [
      VerifiedProofClaim(
        claimId: 'main',
        kind: ProofClaimKind.mainObservation,
        text: statement,
        evidence: evidence,
      ),
    ],
    confidenceBand: ProofConfidenceBand.medium,
    qualityReceipt: ProofQualityReceipt(
      proofType: ProofType.currentObservation,
      confidenceBand: ProofConfidenceBand.medium,
      frequency: ProofFrequency(
        distinctMoments: 1,
        windowStart: _verifiedAt,
        windowEnd: _verifiedAt,
      ),
      trend: ProofTrend.insufficientEvidence,
      strengthOverTime: ProofStrengthOverTime.insufficientEvidence,
      supportingEvidence: evidence,
      counterexamples: const [],
      contradictions: const [],
      missingEvidence: const [],
      firstOccurrence: _verifiedAt,
      lastOccurrence: _verifiedAt,
      generatedAt: _verifiedAt,
    ),
    verifiedAt: _verifiedAt,
    sourceRevisionFingerprint: 'source-revision',
    proofFingerprint: 'proof-fingerprint-full-1',
    semanticFramingFingerprint: ProofFingerprints.semanticFraming(
      statement: statement,
      proofType: ProofType.currentObservation.name,
    ),
    wordingFingerprint: ProofFingerprints.wording(statement),
  );
}

class _Harness {
  _Harness({required this.journal, required this.prefs});
  final JournalStore journal;
  final MobilePrefsStore prefs;
}

Future<_Harness> _newHarness() async {
  final dir = Directory.systemTemp.createTempSync('vm_sync_versioning_');
  final journal = await JournalStore.open(
    '${dir.path}/journal.json',
    encryptAtRest: false,
  );
  final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
  journal.setActiveOwnerKey('user-1');
  await prefs.writeString(JournalOwnershipGuard.ownerKeyPrefsKey, 'user-1');
  await prefs.writeBool(JournalOwnershipGuard.migrationPendingPrefsKey, false);
  return _Harness(journal: journal, prefs: prefs);
}

typedef _PostHandler =
    FutureOr<http.Response> Function(
      int callIndex,
      List<Map<String, dynamic>> entries,
    );
typedef _GetHandler = FutureOr<http.Response> Function();

ApiClient _buildApi({
  required _PostHandler onPost,
  required _GetHandler onGet,
}) {
  var postCallIndex = 0;
  final api = ApiClient(
    httpClient: MockClient((request) async {
      if (request.method == 'POST' && request.url.path == '/api/journal') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final entries = (body['entries'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final index = postCallIndex++;
        return await onPost(index, entries);
      }
      if (request.method == 'GET' && request.url.path == '/api/journal') {
        return await onGet();
      }
      return http.Response('not found', 404);
    }),
    baseUrl: 'https://voice-memory-iota.vercel.app',
  );
  api.setSessionCookie('session=user-1');
  return api;
}

http.Response _pushOk({
  List<String> accepted = const [],
  List<Map<String, dynamic>> rejected = const [],
}) => http.Response(
  jsonEncode({
    'ok': true,
    'accepted': accepted,
    'rejected': rejected,
    'upserted': accepted.length,
  }),
  200,
);

http.Response _pullOk(List<Map<String, dynamic>> entries) =>
    http.Response(jsonEncode({'entries': entries}), 200);

Map<String, dynamic> _rejectionJson({
  required String id,
  required String reason,
  String message = 'conflict',
  JournalEntry? winning,
}) => {
  'id': id,
  'reason': reason,
  'message': message,
  if (winning != null) 'winning': winning.toJson(),
};

void main() {
  setUpAll(() async {
    await AppConfig.initApiResolution();
  });

  test(
    'edit after creation: local edit bumps revision/updatedAt/changeId, pushes, gets accepted, marked synced',
    () async {
      final h = await _newHarness();
      await h.journal.save(_newEntry(id: 'a'));
      final created = (await h.journal.getById('a'))!;
      await h.journal.saveEdit(
        created.copyWith(transcript: 'edited transcript'),
      );
      final edited = (await h.journal.getById('a'))!;
      expect(edited.revision, created.revision + 1);
      expect(edited.changeId, isNot(created.changeId));
      expect(edited.updatedAt, isNot(created.updatedAt));

      final pushedBodies = <Map<String, dynamic>>[];
      final api = _buildApi(
        onPost: (i, entries) {
          pushedBodies.addAll(entries);
          return _pushOk(
            accepted: entries.map((e) => e['id'] as String).toList(),
          );
        },
        onGet: () => _pullOk([]),
      );
      final result = await SyncService(api, h.journal, h.prefs).syncNow();

      expect(pushedBodies, hasLength(1));
      expect(pushedBodies.first['transcript'], 'edited transcript');
      expect(pushedBodies.first['revision'], 2);
      expect(result.pushed, 1);
      expect(result.rejected, 0);
      final synced = await h.journal.getById('a');
      expect(synced!.syncStatus, SyncStatus.synced);
      expect(synced.transcript, 'edited transcript');
    },
  );

  test(
    'multiple offline edits: pendingSyncQueue and the wire payload carry only the latest state, not a history log',
    () async {
      final h = await _newHarness();
      await h.journal.save(_newEntry(id: 'a', transcript: 'v1'));
      var e = (await h.journal.getById('a'))!;
      await h.journal.saveEdit(e.copyWith(transcript: 'v2'));
      e = (await h.journal.getById('a'))!;
      await h.journal.saveEdit(e.copyWith(transcript: 'v3'));
      e = (await h.journal.getById('a'))!;
      await h.journal.saveEdit(e.copyWith(transcript: 'v4'));

      final pending = await h.journal.pendingSyncQueue();
      expect(pending, hasLength(1));
      expect(pending.single.transcript, 'v4');
      expect(pending.single.revision, 4);

      final pushedBatches = <List<Map<String, dynamic>>>[];
      final api = _buildApi(
        onPost: (i, entries) {
          pushedBatches.add(entries);
          return _pushOk(
            accepted: entries.map((e) => e['id'] as String).toList(),
          );
        },
        onGet: () => _pullOk([]),
      );
      final result = await SyncService(api, h.journal, h.prefs).syncNow();

      expect(pushedBatches, hasLength(1));
      expect(pushedBatches.single, hasLength(1));
      expect(pushedBatches.single.first['transcript'], 'v4');
      expect(result.pushed, 1);
    },
  );

  test(
    'concurrent edits from two devices: a STALE_REVISION rejection carrying a winning payload from "device B" overwrites the locally-rejected copy',
    () async {
      final h = await _newHarness();
      await h.journal.save(_newEntry(id: 'a', transcript: 'device-a-v1'));
      var e = (await h.journal.getById('a'))!;
      await h.journal.saveEdit(e.copyWith(transcript: 'device-a-v2'));
      final localCandidate = (await h.journal.getById('a'))!;
      expect(localCandidate.revision, 2);

      final deviceBWinning = localCandidate.copyWith(
        transcript: 'device-b-v2',
        revision: 3,
        updatedAt: localCandidate.updatedAt.add(const Duration(minutes: 1)),
        changeId: 'device-b-change',
        syncStatus: SyncStatus.synced,
      );

      final api = _buildApi(
        onPost: (i, entries) => _pushOk(
          accepted: const [],
          rejected: [
            _rejectionJson(
              id: 'a',
              reason: 'STALE_REVISION',
              winning: deviceBWinning,
            ),
          ],
        ),
        onGet: () => _pullOk([]),
      );
      final result = await SyncService(api, h.journal, h.prefs).syncNow();

      expect(result.pushed, 0);
      expect(result.rejected, 1);
      final after = await h.journal.getById('a');
      expect(after!.transcript, 'device-b-v2');
      expect(after.revision, 3);
      expect(after.changeId, 'device-b-change');
    },
  );

  test(
    'equal revision/updatedAt tie: the deterministic changeId tie-breaker produces the same winner through the sync flow as JournalSyncCompare alone',
    () async {
      final h = await _newHarness();
      final ts = DateTime.utc(2026, 3, 1);
      await h.journal.save(
        _newEntry(
          id: 'a',
        ).copyWith(updatedAt: ts, revision: 5, changeId: 'aaa000'),
      );
      final local = (await h.journal.getById('a'))!;

      final remoteWinner = local.copyWith(
        transcript: 'remote-tie-winner',
        revision: 5,
        updatedAt: ts,
        changeId: 'zzz999',
        syncStatus: SyncStatus.synced,
      );
      // Sanity: the shared comparator alone must already agree remoteWinner
      // wins before we assert the sync flow defers to it.
      expect(
        JournalSyncCompare.winner(local, remoteWinner),
        same(remoteWinner),
      );

      final api = _buildApi(
        onPost: (i, entries) => _pushOk(
          accepted: const [],
          rejected: [
            _rejectionJson(
              id: 'a',
              reason: 'STALE_REVISION',
              winning: remoteWinner,
            ),
          ],
        ),
        onGet: () => _pullOk([]),
      );
      await SyncService(api, h.journal, h.prefs).syncNow();

      final after = await h.journal.getById('a');
      expect(after!.transcript, 'remote-tie-winner');
      expect(after.changeId, 'zzz999');
    },
  );

  test(
    'older/losing local edit is corrected locally from the rejection winning payload and is never marked synced with its own stale content (regression: previously every eligible push was blindly marked synced)',
    () async {
      final h = await _newHarness();
      await h.journal.save(_newEntry(id: 'a', transcript: 'original'));
      var e = (await h.journal.getById('a'))!;
      await h.journal.saveEdit(e.copyWith(transcript: 'stale local edit'));

      final serverWinning = (await h.journal.getById('a'))!.copyWith(
        transcript: 'authoritative server content',
        revision: 3,
        updatedAt: DateTime.utc(2026, 4, 1),
        changeId: 'server-change',
        syncStatus: SyncStatus.synced,
      );

      final api = _buildApi(
        onPost: (i, entries) => _pushOk(
          accepted: const [],
          rejected: [
            _rejectionJson(
              id: 'a',
              reason: 'STALE_REVISION',
              winning: serverWinning,
            ),
          ],
        ),
        onGet: () => _pullOk([]),
      );
      final result = await SyncService(api, h.journal, h.prefs).syncNow();

      expect(result.pushed, 0);
      expect(result.rejected, 1);
      final after = await h.journal.getById('a');
      expect(after!.transcript, 'authoritative server content');
      expect(after.transcript, isNot('stale local edit'));
      expect(after.revision, 3);
    },
  );

  test(
    'local delete propagation: a soft-deleted entry appears as a tombstone in the next push batch',
    () async {
      final h = await _newHarness();
      await h.journal.save(_newEntry(id: 'a'));
      await h.journal.delete('a');

      final pushedEntries = <Map<String, dynamic>>[];
      final api = _buildApi(
        onPost: (i, entries) {
          pushedEntries.addAll(entries);
          return _pushOk(
            accepted: entries.map((e) => e['id'] as String).toList(),
          );
        },
        onGet: () => _pullOk([]),
      );
      final result = await SyncService(api, h.journal, h.prefs).syncNow();

      expect(pushedEntries, hasLength(1));
      expect(pushedEntries.single['id'], 'a');
      expect(pushedEntries.single['deletedAt'], isNotNull);
      expect(result.pushed, 1);
      final after = await h.journal.getByIdIncludingTombstones('a');
      expect(after!.isDeleted, isTrue);
      expect(after.syncStatus, SyncStatus.synced);
    },
  );

  test(
    'remote delete propagation: pulling a tombstone for a locally-live entry deletes it locally',
    () async {
      final h = await _newHarness();
      await h.journal.save(
        _newEntry(id: 'a', transcript: 'still alive locally'),
      );
      final local = (await h.journal.getById('a'))!;

      // Recent, not retention-expired — this test is about merge behavior,
      // not about compaction (see the dedicated retention/compaction test).
      final deletionTime = DateTime.now().toUtc();
      final remoteTombstone = local.copyWith(
        deletedAt: deletionTime,
        updatedAt: deletionTime,
        revision: local.revision + 1,
        changeId: 'remote-delete-change',
        syncStatus: SyncStatus.synced,
      );

      final api = _buildApi(
        onPost: (i, entries) =>
            _pushOk(accepted: entries.map((e) => e['id'] as String).toList()),
        onGet: () => _pullOk([remoteTombstone.toJson()]),
      );
      await SyncService(api, h.journal, h.prefs).syncNow();

      final visible = await h.journal.loadAll();
      expect(visible.where((e) => e.id == 'a'), isEmpty);
      final withTombstones = await h.journal.loadAllIncludingTombstones();
      final tomb = withTombstones.firstWhere((e) => e.id == 'a');
      expect(tomb.isDeleted, isTrue);
    },
  );

  test(
    'deleted entry never resurrects from a stale/duplicate non-deleted pull response',
    () async {
      final h = await _newHarness();
      await h.journal.save(_newEntry(id: 'a'));
      await h.journal.delete('a');
      await h.journal.markSynced('a');
      final tomb = (await h.journal.getByIdIncludingTombstones('a'))!;
      expect(tomb.isDeleted, isTrue);
      expect(tomb.syncStatus, SyncStatus.synced);

      final staleNonDeleted = tomb.copyWith(
        deletedAt: null,
        revision: tomb.revision - 1,
        updatedAt: tomb.updatedAt.subtract(const Duration(minutes: 5)),
        changeId: 'stale-duplicate-change',
      );

      final api = _buildApi(
        onPost: (i, entries) =>
            _pushOk(accepted: entries.map((e) => e['id'] as String).toList()),
        onGet: () => _pullOk([staleNonDeleted.toJson()]),
      );
      await SyncService(api, h.journal, h.prefs).syncNow();

      final after = await h.journal.getByIdIncludingTombstones('a');
      expect(after!.isDeleted, isTrue);
      final visible = await h.journal.loadAll();
      expect(visible.where((e) => e.id == 'a'), isEmpty);
    },
  );

  test(
    'tombstone retention and compaction: syncNow purges acknowledged+expired tombstones but keeps pending or fresh ones',
    () async {
      final h = await _newHarness();

      await h.journal.save(_newEntry(id: 'old-acked'));
      await h.journal.delete('old-acked');
      await h.journal.markSynced('old-acked');
      final oldAcked = (await h.journal.getByIdIncludingTombstones(
        'old-acked',
      ))!;
      await h.journal.save(
        oldAcked.copyWith(
          deletedAt: DateTime.now().toUtc().subtract(const Duration(days: 40)),
        ),
      );

      await h.journal.save(_newEntry(id: 'recent-acked'));
      await h.journal.delete('recent-acked');
      await h.journal.markSynced('recent-acked');

      await h.journal.save(_newEntry(id: 'old-pending'));
      await h.journal.delete('old-pending');
      final oldPending = (await h.journal.getByIdIncludingTombstones(
        'old-pending',
      ))!;
      await h.journal.save(
        oldPending.copyWith(
          deletedAt: DateTime.now().toUtc().subtract(const Duration(days: 40)),
        ),
      );

      final api = _buildApi(
        onPost: (i, entries) {
          final ids = entries.map((e) => e['id'] as String).toList();
          // Deliberately never let 'old-pending' get acknowledged this
          // cycle, so we prove retention age alone never purges a
          // still-pending tombstone.
          final accepted = ids.where((id) => id != 'old-pending').toList();
          final rejected = ids.contains('old-pending')
              ? [
                  _rejectionJson(
                    id: 'old-pending',
                    reason: 'INVALID_ENTRY',
                    message: 'simulated validation failure',
                  ),
                ]
              : const <Map<String, dynamic>>[];
          return _pushOk(accepted: accepted, rejected: rejected);
        },
        onGet: () => _pullOk([]),
      );
      await SyncService(api, h.journal, h.prefs).syncNow();

      final all = await h.journal.loadAllIncludingTombstones();
      expect(all.any((e) => e.id == 'old-acked'), isFalse);
      expect(all.any((e) => e.id == 'recent-acked'), isTrue);
      expect(all.any((e) => e.id == 'old-pending'), isTrue);
      final stillPending = await h.journal.getByIdIncludingTombstones(
        'old-pending',
      );
      expect(stillPending!.syncStatus, isNot(SyncStatus.synced));
    },
  );

  test(
    'all metadata (biomarkers, ownerKey, verifiedProof, parentHookId) survives a full push+accept+pull+merge cycle',
    () async {
      final h = await _newHarness();
      final entry = JournalEntry(
        id: 'meta-1',
        createdAt: DateTime.utc(2026, 6, 1),
        transcript: 'metadata round trip',
        durationSeconds: 42,
        reflection: _reflection(),
        biomarkers: const CognitiveBiomarkers(
          lexicalDiversity: 0.4,
          cohesionDrift: 0.2,
          emotionalVolatility: 0.6,
        ),
        ownerKey: 'user-1',
        parentHookId: 'hook-42',
        verifiedProof: _fullVerifiedProof(),
        wasGrounded: true,
      );
      await h.journal.save(entry);
      // Note: biomarkers are recomputed from the transcript on every save
      // (JournalStore._cognitiveAnalyzer) — that recomputation is
      // orthogonal to this test, which only asserts that whatever was
      // actually persisted survives the sync round trip unchanged.
      final initiallySaved = (await h.journal.getById('meta-1'))!;
      final beforeJson = initiallySaved.toJson();

      Map<String, dynamic>? echoedPush;
      final api = _buildApi(
        onPost: (i, entries) {
          echoedPush = entries.single;
          return _pushOk(accepted: [entries.single['id'] as String]);
        },
        onGet: () => _pullOk([echoedPush!]),
      );
      await SyncService(api, h.journal, h.prefs).syncNow();

      final after = await h.journal.getById('meta-1');
      expect(after, isNotNull);
      final afterJson = Map<String, dynamic>.from(after!.toJson())
        ..['_syncStatus'] = beforeJson['_syncStatus'];
      expect(afterJson, beforeJson);
      expect(
        after.biomarkers?.lexicalDiversity,
        initiallySaved.biomarkers?.lexicalDiversity,
      );
      expect(
        after.biomarkers?.cohesionDrift,
        initiallySaved.biomarkers?.cohesionDrift,
      );
      expect(
        after.biomarkers?.emotionalVolatility,
        initiallySaved.biomarkers?.emotionalVolatility,
      );
      expect(after.ownerKey, 'user-1');
      expect(after.parentHookId, 'hook-42');
      expect(after.wasGrounded, isTrue);
      expect(after.verifiedProof?.proofId, 'proof-full-1');
      expect(
        after.verifiedProof?.claims.single.text,
        entry.verifiedProof!.claims.single.text,
      );
    },
  );

  test(
    'retry after partial batch success: 250 pending entries batch into 2 POST calls, the second fails, and only the remaining ~50 are re-sent on the next syncNow()',
    () async {
      final h = await _newHarness();
      for (var i = 0; i < 250; i++) {
        await h.journal.save(_newEntry(id: 'e$i', transcript: 'entry $i'));
      }

      final postBatchSizes = <int>[];
      final api = _buildApi(
        onPost: (index, entries) {
          postBatchSizes.add(entries.length);
          if (index == 1) {
            throw Exception('simulated network failure on second batch');
          }
          return _pushOk(
            accepted: entries.map((e) => e['id'] as String).toList(),
          );
        },
        onGet: () => _pullOk([]),
      );

      final sync = SyncService(api, h.journal, h.prefs);
      final firstResult = await sync.syncNow();

      expect(postBatchSizes, [200, 50]);
      expect(firstResult.cloudSyncSucceeded, isFalse);
      expect(firstResult.pushed, 200);

      final stillPendingAfterFirst = await h.journal.pendingSyncQueue();
      expect(stillPendingAfterFirst, hasLength(50));

      final secondResult = await sync.syncNow();
      expect(postBatchSizes, [200, 50, 50]);
      expect(secondResult.cloudSyncSucceeded, isTrue);
      expect(secondResult.pushed, 50);

      final stillPendingAfterSecond = await h.journal.pendingSyncQueue();
      expect(stillPendingAfterSecond, isEmpty);
    },
  );
}
