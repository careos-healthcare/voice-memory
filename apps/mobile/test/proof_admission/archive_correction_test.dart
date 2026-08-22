import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical choices are stable and complete', () {
    expect(ArchiveCorrectionChoice.values.map((value) => value.name), [
      'exactlyRight',
      'partlyRight',
      'wrong',
      'wrongWording',
      'wrongEvidence',
      'ignoreForever',
    ]);
  });

  test('serializes and restores every safe structural field', () {
    final correction = ArchiveCorrection(
      correctionId: 'correction-1',
      archiveScope: 'archive-1',
      targetProofId: 'proof-1',
      targetProofFingerprint: 'proof-fingerprint',
      semanticFramingFingerprint: 'semantic-fingerprint',
      wordingFingerprint: 'wording-fingerprint',
      affectedEvidenceRefs: const ['evidence-1', 'evidence-2'],
      choice: ArchiveCorrectionChoice.wrongWording,
      qualifier: ArchiveCorrectionQualifier.scopeTooBroad,
      createdAt: DateTime.utc(2026, 8, 1, 9),
      updatedAt: DateTime.utc(2026, 8, 2, 10),
      sourceSurface: 'archive_timeline',
      superseded: true,
    );

    final json = correction.toJson();
    final restored = ArchiveCorrection.fromJson(json);

    expect(restored.correctionId, correction.correctionId);
    expect(restored.archiveScope, correction.archiveScope);
    expect(restored.targetProofId, correction.targetProofId);
    expect(restored.targetProofFingerprint, correction.targetProofFingerprint);
    expect(
      restored.semanticFramingFingerprint,
      correction.semanticFramingFingerprint,
    );
    expect(restored.wordingFingerprint, correction.wordingFingerprint);
    expect(restored.affectedEvidenceRefs, correction.affectedEvidenceRefs);
    expect(restored.choice, correction.choice);
    expect(restored.qualifier, correction.qualifier);
    expect(restored.createdAt, correction.createdAt);
    expect(restored.updatedAt, correction.updatedAt);
    expect(restored.sourceSurface, correction.sourceSurface);
    expect(restored.schemaVersion, correction.schemaVersion);
    expect(restored.superseded, isTrue);
  });

  test('never reads or writes plaintext notes or private text', () {
    final restored = ArchiveCorrection.fromJson({
      'correctionId': 'correction-1',
      'archiveScope': 'archive-1',
      'targetProofId': 'proof-1',
      'choice': 'wrong',
      'createdAt': '2026-08-01T09:00:00.000Z',
      'updatedAt': '2026-08-01T09:00:00.000Z',
      'privateNotes': 'must not survive',
      'note': 'must not survive',
      'text': 'must not survive',
      'rawJournalText': 'must not survive',
    });

    final json = restored.toJson();
    expect(json.keys, isNot(contains('privateNotes')));
    expect(json.keys, isNot(contains('note')));
    expect(json.keys, isNot(contains('text')));
    expect(json.keys, isNot(contains('rawJournalText')));
    expect(json.values, isNot(contains('must not survive')));
  });
}