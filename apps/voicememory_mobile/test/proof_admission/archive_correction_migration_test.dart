import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_migration.dart';

void main() {
  final seed = ArchiveCorrectionMigrationSeed(
    correctionId: 'migrated-1',
    archiveScope: 'archive-1',
    targetProofId: 'proof-1',
    targetProofFingerprint: 'proof-fingerprint',
    semanticFramingFingerprint: 'semantic-fingerprint',
    wordingFingerprint: 'wording-fingerprint',
    affectedEvidenceRefs: const ['evidence-1'],
    createdAt: DateTime.utc(2026, 8, 1),
    sourceSurface: 'legacy_migration',
  );

  test('migrates structurally compatible InsightFeedback choices', () {
    final fits = ArchiveCorrectionMigration.fromInsightFeedbackJson({
      'choice': 'fits',
    }, seed: seed);
    final notQuite = ArchiveCorrectionMigration.fromInsightFeedbackJson({
      'choice': 'notQuite',
    }, seed: seed);
    final tooEarly = ArchiveCorrectionMigration.fromInsightFeedbackJson({
      'choice': 'tooEarly',
    }, seed: seed);

    expect(fits?.choice, ArchiveCorrectionChoice.exactlyRight);
    expect(notQuite?.choice, ArchiveCorrectionChoice.partlyRight);
    expect(tooEarly?.choice, ArchiveCorrectionChoice.partlyRight);
    expect(tooEarly?.qualifier, ArchiveCorrectionQualifier.tooEarly);
  });

  test('does not misclassify saveAsWatchTheme as a correction', () {
    final migrated = ArchiveCorrectionMigration.fromInsightFeedbackJson({
      'choice': 'saveAsWatchTheme',
    }, seed: seed);
    expect(migrated, isNull);
  });

  test('migrates structurally compatible ProofQuality feedback', () {
    final useful = ArchiveCorrectionMigration.fromProofQualityJson({
      'feedbackState': 'useful',
    }, seed: seed);
    final tooVague = ArchiveCorrectionMigration.fromProofQualityJson({
      'feedbackState': 'tooVague',
    }, seed: seed);
    final notRelevant = ArchiveCorrectionMigration.fromProofQualityJson({
      'feedbackState': 'notRelevant',
    }, seed: seed);

    expect(useful?.choice, ArchiveCorrectionChoice.exactlyRight);
    expect(tooVague?.choice, ArchiveCorrectionChoice.wrongWording);
    expect(notRelevant?.choice, ArchiveCorrectionChoice.wrongEvidence);
  });

  test('uses safe seed fields and legacy timestamp without importing UI', () {
    final migrated = ArchiveCorrectionMigration.fromProofQualityJson({
      'feedbackState': 'useful',
      'answeredAt': '2026-08-03T12:30:00.000Z',
      'privateNotes': 'do not migrate',
    }, seed: seed)!;

    expect(migrated.archiveScope, seed.archiveScope);
    expect(migrated.targetProofFingerprint, seed.targetProofFingerprint);
    expect(migrated.createdAt, DateTime.utc(2026, 8, 3, 12, 30));
    expect(migrated.toJson().values, isNot(contains('do not migrate')));
  });
}
