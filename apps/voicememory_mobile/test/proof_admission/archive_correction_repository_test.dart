import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_policy.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_repository.dart';

ArchiveCorrection _correction({
  required String id,
  required String archive,
  required ArchiveCorrectionChoice choice,
  required int minute,
  String targetProofId = 'proof-1',
  String targetProofFingerprint = 'proof-fingerprint',
}) {
  final timestamp = DateTime.utc(2026, 8, 1, 10, minute);
  return ArchiveCorrection(
    correctionId: id,
    archiveScope: archive,
    targetProofId: targetProofId,
    targetProofFingerprint: targetProofFingerprint,
    semanticFramingFingerprint: 'semantic-fingerprint',
    wordingFingerprint: 'wording-fingerprint',
    affectedEvidenceRefs: const ['evidence-1'],
    choice: choice,
    createdAt: timestamp,
    updatedAt: timestamp,
    sourceSurface: 'test',
  );
}

void main() {
  test(
    'saving a newer correction supersedes the active target correction',
    () async {
      final repository = InMemoryArchiveCorrectionRepository();
      await repository.save(
        _correction(
          id: 'first',
          archive: 'archive-1',
          choice: ArchiveCorrectionChoice.wrong,
          minute: 1,
        ),
      );
      await repository.save(
        _correction(
          id: 'second',
          archive: 'archive-1',
          choice: ArchiveCorrectionChoice.exactlyRight,
          minute: 2,
        ),
      );

      final history = await repository.historyForTarget(
        archiveScope: 'archive-1',
        targetProofId: 'proof-1',
      );
      expect(history, hasLength(2));
      expect(history.first.correctionId, 'second');
      expect(history.first.superseded, isFalse);
      expect(history.last.correctionId, 'first');
      expect(history.last.superseded, isTrue);
      expect(
        (await repository.activeForTarget(
          archiveScope: 'archive-1',
          targetProofId: 'proof-1',
        ))?.correctionId,
        'second',
      );
    },
  );

  test('same proof identity remains isolated between archives', () async {
    final repository = InMemoryArchiveCorrectionRepository();
    await repository.save(
      _correction(
        id: 'archive-a',
        archive: 'archive-a',
        choice: ArchiveCorrectionChoice.wrong,
        minute: 1,
      ),
    );
    await repository.save(
      _correction(
        id: 'archive-b',
        archive: 'archive-b',
        choice: ArchiveCorrectionChoice.exactlyRight,
        minute: 2,
      ),
    );

    final archiveA = await repository.historyForArchive('archive-a');
    final archiveB = await repository.historyForArchive('archive-b');
    expect(archiveA.single.correctionId, 'archive-a');
    expect(archiveA.single.superseded, isFalse);
    expect(archiveB.single.correctionId, 'archive-b');
    expect(archiveB.single.superseded, isFalse);
  });

  test('ignore forever remains enforced after superseding', () async {
    final repository = InMemoryArchiveCorrectionRepository();
    final lookup = ArchiveCorrectionPolicyLookup(repository);
    await repository.save(
      _correction(
        id: 'ignore',
        archive: 'archive-1',
        choice: ArchiveCorrectionChoice.ignoreForever,
        minute: 1,
      ),
    );
    await repository.save(
      _correction(
        id: 'later',
        archive: 'archive-1',
        choice: ArchiveCorrectionChoice.exactlyRight,
        minute: 2,
      ),
    );

    final policy = await lookup.forTarget(
      archiveScope: 'archive-1',
      targetProofId: 'proof-1',
    );
    expect(policy.activeCorrection?.correctionId, 'later');
    expect(policy.isIgnoredForever, isTrue);
    expect(policy.allowsAdmission, isFalse);
  });

  test('policy exposes categorized history counts', () async {
    final repository = InMemoryArchiveCorrectionRepository();
    final lookup = ArchiveCorrectionPolicyLookup(repository);
    final choices = [
      ArchiveCorrectionChoice.exactlyRight,
      ArchiveCorrectionChoice.partlyRight,
      ArchiveCorrectionChoice.wrong,
      ArchiveCorrectionChoice.wrongWording,
      ArchiveCorrectionChoice.wrongEvidence,
    ];

    for (var index = 0; index < choices.length; index++) {
      await repository.save(
        _correction(
          id: 'correction-$index',
          archive: 'archive-1',
          choice: choices[index],
          minute: index,
        ),
      );
    }

    final policy = await lookup.forTarget(
      archiveScope: 'archive-1',
      targetProofId: 'proof-1',
    );
    expect(policy.positiveHistoryCount, 2);
    expect(policy.negativeHistoryCount, 1);
    expect(policy.wordingHistoryCount, 1);
    expect(policy.evidenceHistoryCount, 1);
  });
}
