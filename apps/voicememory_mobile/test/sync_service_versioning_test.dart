// Encrypted sync integration — covers SyncService.syncNow() push/pull merge,
// tombstones, ownership partitioning, and metadata round-trips via
// `/api/sync/*` encrypted blobs (not legacy plaintext `/api/journal`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/network/api_failure.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_fingerprints.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/journal_ownership_guard.dart';
import 'package:voicememory_mobile/services/sync_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

import 'helpers/encrypted_sync_test_helpers.dart';
import 'helpers/test_sync_service.dart';

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
  _Harness({
    required this.journal,
    required this.prefs,
    required this.keyStore,
    required this.syncApi,
  });

  final JournalStore journal;
  final MobilePrefsStore prefs;
  final InMemorySyncMasterKeyStore keyStore;
  final RecordingSyncApiClient syncApi;

  Future<SyncService> syncService() => createTestSyncService(
    syncApi: syncApi,
    journal: journal,
    prefs: prefs,
    keyStore: keyStore,
  );
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
  final keyStore = InMemorySyncMasterKeyStore();
  final syncApi = RecordingSyncApiClient(
    keyStore: keyStore,
    accountNamespace: 'user-1',
  );
  return _Harness(
    journal: journal,
    prefs: prefs,
    keyStore: keyStore,
    syncApi: syncApi,
  );
}

void main() {
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

      final result = await (await h.syncService()).syncNow();

      expect(h.syncApi.pushedSnapshots.single, hasLength(1));
      expect(
        h.syncApi.pushedSnapshots.single.single.transcript,
        'edited transcript',
      );
      expect(h.syncApi.pushedSnapshots.single.single.revision, 2);
      expect(result.pushed, 1);
      expect(result.rejected, 0);
      final synced = await h.journal.getById('a');
      expect(synced!.syncStatus, SyncStatus.synced);
      expect(synced.transcript, 'edited transcript');
    },
  );

  test(
    'multiple offline edits: pendingSyncQueue carries only the latest state, not a history log',
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

      final result = await (await h.syncService()).syncNow();

      expect(h.syncApi.pushedSnapshots, hasLength(1));
      expect(h.syncApi.pushedSnapshots.single, hasLength(1));
      expect(h.syncApi.pushedSnapshots.single.single.transcript, 'v4');
      expect(result.pushed, 1);
    },
  );

  test(
    'remote winning snapshot from another device overwrites stale local edits on pull merge',
    () async {
      final h = await _newHarness();
      await h.journal.save(_newEntry(id: 'a', transcript: 'device-a-v1'));
      var e = (await h.journal.getById('a'))!;
      await h.journal.saveEdit(e.copyWith(transcript: 'device-a-v2'));
      final localCandidate = (await h.journal.getById('a'))!;

      final deviceBWinning = localCandidate.copyWith(
        transcript: 'device-b-v2',
        revision: 3,
        updatedAt: localCandidate.updatedAt.add(const Duration(minutes: 1)),
        changeId: 'device-b-change',
        syncStatus: SyncStatus.synced,
      );
      h.syncApi.pullEntries = [deviceBWinning];

      final result = await (await h.syncService()).syncNow();

      expect(result.pulled, 1);
      final after = await h.journal.getById('a');
      expect(after!.transcript, 'device-b-v2');
      expect(after.revision, 3);
      expect(after.changeId, 'device-b-change');
    },
  );

  test(
    'equal revision/updatedAt tie: deterministic changeId tie-breaker picks remote winner on pull merge',
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
      expect(
        JournalSyncCompare.winner(local, remoteWinner),
        same(remoteWinner),
      );
      h.syncApi.pullEntries = [remoteWinner];

      await (await h.syncService()).syncNow();

      final after = await h.journal.getById('a');
      expect(after!.transcript, 'remote-tie-winner');
      expect(after.changeId, 'zzz999');
    },
  );

  test(
    'authoritative remote snapshot replaces stale local content after sync',
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
      h.syncApi.pullEntries = [serverWinning];

      final result = await (await h.syncService()).syncNow();

      expect(result.pulled, 1);
      final after = await h.journal.getById('a');
      expect(after!.transcript, 'authoritative server content');
      expect(after.transcript, isNot('stale local edit'));
      expect(after.revision, 3);
    },
  );

  test(
    'local delete propagation: a soft-deleted entry is included in the encrypted push snapshot',
    () async {
      final h = await _newHarness();
      await h.journal.save(_newEntry(id: 'a'));
      await h.journal.delete('a');

      final result = await (await h.syncService()).syncNow();

      expect(h.syncApi.pushedSnapshots.single, hasLength(1));
      expect(h.syncApi.pushedSnapshots.single.single.id, 'a');
      expect(h.syncApi.pushedSnapshots.single.single.deletedAt, isNotNull);
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

      final deletionTime = DateTime.now().toUtc();
      final remoteTombstone = local.copyWith(
        deletedAt: deletionTime,
        updatedAt: deletionTime,
        revision: local.revision + 1,
        changeId: 'remote-delete-change',
        syncStatus: SyncStatus.synced,
      );
      h.syncApi.pullEntries = [remoteTombstone];

      await (await h.syncService()).syncNow();

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
      h.syncApi.pullEntries = [staleNonDeleted];

      await (await h.syncService()).syncNow();

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

      await (await h.syncService()).syncNow();

      final all = await h.journal.loadAllIncludingTombstones();
      expect(all.any((e) => e.id == 'old-acked'), isFalse);
      expect(all.any((e) => e.id == 'recent-acked'), isTrue);
      expect(all.any((e) => e.id == 'old-pending'), isTrue);
      final stillPending = await h.journal.getByIdIncludingTombstones(
        'old-pending',
      );
      expect(stillPending!.syncStatus, SyncStatus.synced);
    },
  );

  test(
    'all metadata (biomarkers, ownerKey, verifiedProof, parentHookId) survives a full push+pull+merge cycle',
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
      final initiallySaved = (await h.journal.getById('meta-1'))!;
      final beforeJson = initiallySaved.toJson();

      await (await h.syncService()).syncNow();
      final pushed = h.syncApi.pushedSnapshots.single.single;
      h.syncApi.pullEntries = [pushed];
      await (await h.syncService()).syncNow();

      final after = await h.journal.getById('meta-1');
      expect(after, isNotNull);
      final afterJson = Map<String, dynamic>.from(after!.toJson())
        ..['_syncStatus'] = beforeJson['_syncStatus'];
      expect(afterJson, beforeJson);
      expect(after.ownerKey, 'user-1');
      expect(after.parentHookId, 'hook-42');
      expect(after.wasGrounded, isTrue);
      expect(after.verifiedProof?.proofId, 'proof-full-1');
    },
  );

  test(
    'retry after push failure: failed encrypted push leaves entries pending, next syncNow succeeds',
    () async {
      final h = await _newHarness();
      for (var i = 0; i < 250; i++) {
        await h.journal.save(_newEntry(id: 'e$i', transcript: 'entry $i'));
      }

      h.syncApi.syncPushError = const ApiFailureOffline();
      final sync = await h.syncService();
      final firstResult = await sync.syncNow();

      expect(firstResult.cloudSyncSucceeded, isFalse);
      expect(firstResult.pushed, 0);
      expect(await h.journal.pendingSyncQueue(), hasLength(250));

      h.syncApi.syncPushError = null;
      final secondResult = await sync.syncNow();
      expect(secondResult.cloudSyncSucceeded, isTrue);
      expect(secondResult.pushed, 250);
      expect(h.syncApi.pushedSnapshots.last, hasLength(250));
      expect(await h.journal.pendingSyncQueue(), isEmpty);
    },
  );
}
