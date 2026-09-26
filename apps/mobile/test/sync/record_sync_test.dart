import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/sync/e2ee_journal_sync.dart';
import 'package:archiveme_mobile/sync/record_sync.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final kdf = Argon2id(
    parallelism: 1,
    memory: 32,
    iterations: 1,
    hashLength: 32,
  );

  setUp(() => AccountSyncKey.debugKdf = kdf);
  tearDown(() => AccountSyncKey.debugKdf = null);

  EntryFieldState fields({
    required String transcript,
    required String base,
    required DateTime transcriptAt,
    required String transcriptDevice,
    String title = '',
    DateTime? titleAt,
    String titleDevice = 'a',
    String mood = '',
    DateTime? moodAt,
    String moodDevice = 'a',
    String place = '',
    DateTime? placeAt,
    String placeDevice = 'a',
    List<String> blobIds = const [],
  }) {
    final stamp = DateTime.utc(2026, 1, 1);
    return EntryFieldState(
      transcript: transcript,
      baseTranscript: base,
      transcriptUpdatedAt: transcriptAt,
      transcriptDeviceId: transcriptDevice,
      title: title,
      titleUpdatedAt: titleAt ?? stamp,
      titleDeviceId: titleDevice,
      mood: mood,
      moodUpdatedAt: moodAt ?? stamp,
      moodDeviceId: moodDevice,
      place: place,
      placeUpdatedAt: placeAt ?? stamp,
      placeDeviceId: placeDevice,
      tags: const [],
      tagsUpdatedAt: stamp,
      tagsDeviceId: 'a',
      blobIds: blobIds,
    );
  }

  test('encrypt and decrypt a record, and a wrong passphrase fails cleanly', () async {
    expect(AccountKdfParams.production.memoryKiB, 64 * 1024);
    expect(AccountKdfParams.production.iterations, 3);
    final account = AccountSyncKey.generate(Random(4));
    const passphrase = 'correct horse battery';
    final recovery = AccountSyncKey.recoveryPhrase(Random(9));
    final bundle = await AccountSyncKey.wrap(
      accountKey: account,
      passphrase: passphrase,
      recoveryPhrase: recovery,
    );
    final opened = await AccountSyncKey.unwrap(
      wrapped: bundle.wrappedByPassphrase,
      secret: passphrase,
    );
    expect(opened, account);

    const transcript = 'the river was high after the rain';
    final state = fields(
      transcript: transcript,
      base: transcript,
      transcriptAt: DateTime.utc(2026, 3, 12),
      transcriptDevice: 'iphone-a',
    );
    final sealed = await RecordSync.sealEntry(
      accountKey: account,
      recordId: 'river',
      state: state,
      version: 1,
      deviceId: 'iphone-a',
    );
    final restored = await RecordSync.openEntry(accountKey: opened, record: sealed);
    expect(restored.transcript, transcript);

    final body = RecordSync.pushBody([sealed]);
    expect(RecordSync.bodyContainsPlaintext(body, transcript), isFalse);
    expect(jsonEncode(bundle.toJson()).contains(transcript), isFalse);

    await expectLater(
      AccountSyncKey.unwrap(
        wrapped: bundle.wrappedByPassphrase,
        secret: 'not-the-passphrase',
      ),
      throwsA(isA<AccountKeyUnlockFailed>()),
    );
  });

  test('a tombstone removes the entry on the other device', () async {
    final account = AccountSyncKey.generate(Random(3));
    final kept = fields(
      transcript: 'kept',
      base: 'kept',
      transcriptAt: DateTime.utc(2026, 3, 1),
      transcriptDevice: 'a',
    );
    final gone = fields(
      transcript: 'gone',
      base: 'gone',
      transcriptAt: DateTime.utc(2026, 3, 1),
      transcriptDevice: 'a',
    );
    final tombstone = await RecordSync.tombstone(
      accountKey: account,
      recordId: 'gone',
      deletedAt: DateTime.utc(2026, 3, 2),
      deviceId: 'iphone-a',
      version: 2,
    );
    final next = RecordSync.apply(
      local: {'kept': kept, 'gone': gone},
      remote: [
        (id: 'gone', tombstone: tombstone, entry: null),
      ],
      now: DateTime.utc(2026, 3, 3),
    );
    expect(next.keys, ['kept']);
    expect(
      tombstone.tombstoneActive(DateTime.utc(2026, 3, 2).add(const Duration(days: 181))),
      isFalse,
    );
  });

  test('two devices that both edit the transcript keep both versions', () {
    final base = DateTime.utc(2026, 3, 1);
    final local = fields(
      transcript: 'the river was high',
      base: 'the river',
      transcriptAt: DateTime.utc(2026, 3, 2),
      transcriptDevice: 'iphone-a',
      title: 'Morning',
      titleAt: DateTime.utc(2026, 3, 2),
      titleDevice: 'iphone-a',
    );
    final remote = fields(
      transcript: 'the river fell',
      base: 'the river',
      transcriptAt: DateTime.utc(2026, 3, 2, 1),
      transcriptDevice: 'iphone-b',
    );
    final merged = RecordSync.merge(local, remote);
    expect(merged.hasConflict, isTrue);
    expect(merged.conflict!.local, 'the river was high');
    expect(merged.conflict!.remote, 'the river fell');
    expect(merged.state.title, 'Morning');
    expect(merged.state.transcript, 'the river');
  });

  test('offline edits on two devices converge field by field', () {
    final baseTime = DateTime.utc(2026, 3, 1);
    final phone = fields(
      transcript: 'hello',
      base: 'hello',
      transcriptAt: baseTime,
      transcriptDevice: 'iphone',
      title: 'Morning',
      titleAt: DateTime.utc(2026, 3, 2),
      titleDevice: 'iphone',
    );
    final android = fields(
      transcript: 'hello',
      base: 'hello',
      transcriptAt: baseTime,
      transcriptDevice: 'android',
      place: 'Park',
      placeAt: DateTime.utc(2026, 3, 2, 1),
      placeDevice: 'android',
      mood: 'Calm',
      moodAt: DateTime.utc(2026, 3, 2, 1),
      moodDevice: 'android',
    );
    final merged = RecordSync.merge(phone, android);
    expect(merged.hasConflict, isFalse);
    expect(merged.state.title, 'Morning');
    expect(merged.state.place, 'Park');
    expect(merged.state.mood, 'Calm');
    expect(merged.state.transcript, 'hello');
    expect(RecordSyncSchedule.pushDebounce, const Duration(seconds: 5));
    expect(RecordSyncSchedule.foregroundPull, const Duration(minutes: 15));
    expect(RecordSyncSchedule.pullDue(null, DateTime.utc(2026, 3, 2)), isTrue);
  });

  test('a recovery key on a fresh install restores the entry and its media', () async {
    final account = AccountSyncKey.generate(Random(8));
    const passphrase = 'first-phone-passphrase';
    final recovery = AccountSyncKey.recoveryPhrase(Random(11));
    final bundle = await AccountSyncKey.wrap(
      accountKey: account,
      passphrase: passphrase,
      recoveryPhrase: recovery,
    );
    const transcript = 'saved on the first phone';
    final sealed = await RecordSync.sealEntry(
      accountKey: account,
      recordId: 'walk',
      version: 1,
      deviceId: 'iphone-a',
      state: fields(
        transcript: transcript,
        base: transcript,
        transcriptAt: DateTime.utc(2025, 3, 12),
        transcriptDevice: 'iphone-a',
        blobIds: const ['photo-0'],
      ),
    );
    final media = List<int>.generate(32, (index) => index);
    final chunks = await RecordSync.sealMedia(
      accountKey: account,
      bytes: media,
      blobPrefix: 'photo',
    );

    final fresh = await AccountSyncKey.unwrap(
      wrapped: bundle.wrappedByRecovery,
      secret: recovery,
    );
    final entry = await RecordSync.openEntry(accountKey: fresh, record: sealed);
    final restoredMedia = await RecordSync.openMedia(
      accountKey: fresh,
      chunks: chunks,
    );
    expect(fresh, account);
    expect(entry.transcript, transcript);
    expect(entry.blobIds, ['photo-0']);
    expect(restoredMedia, media);
    expect(chunks.single.ciphertext.contains('saved on the first phone'), isFalse);

    final now = DateTime.utc(2026, 9, 26, 12);
    final handoff = await RecordSync.issuePairTicket(
      accountKey: account,
      id: 'pair-1',
      now: now,
      random: Random(2),
    );
    expect(jsonEncode(handoff.ticket.toJson()).contains(transcript), isFalse);
    final claimed = await RecordSync.claimPairTicket(
      ticket: handoff.ticket,
      oneTimeKey: handoff.oneTimeKey,
      now: now.add(const Duration(minutes: 4)),
    );
    expect(claimed, account);
    expect(
      () => RecordSync.claimPairTicket(
        ticket: handoff.ticket,
        oneTimeKey: handoff.oneTimeKey,
        now: now.add(const Duration(minutes: 6)),
      ),
      throwsStateError,
    );
  });

  test('a snapshot upgrades into one sealed record per entry', () async {
    final account = AccountSyncKey.generate(Random(1));
    final entry = JournalEntry(
      id: 'legacy',
      createdAt: DateTime.utc(2024, 1, 2),
      transcript: 'from the old snapshot',
      durationSeconds: 3,
      reflection: const Reflection(
        mood: 'Calm',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      updatedAt: DateTime.utc(2024, 1, 2, 8),
    );
    final records = await E2eeJournalSync.migrateSnapshot(
      accountKey: account,
      entries: [entry],
      deviceId: 'iphone',
    );
    final opened = await RecordSync.openEntry(
      accountKey: account,
      record: records.single,
    );
    expect(opened.transcript, 'from the old snapshot');
    expect(opened.mood, 'Calm');
    expect(records.single.toJson().toString().contains('from the old snapshot'), isFalse);
  });
}
