import 'archive_correction.dart';
import 'archive_correction_repository.dart';

class ArchiveCorrectionPolicy {
  const ArchiveCorrectionPolicy({
    required this.activeCorrection,
    required this.positiveHistoryCount,
    required this.negativeHistoryCount,
    required this.wordingHistoryCount,
    required this.evidenceHistoryCount,
    required this.isIgnoredForever,
  });

  final ArchiveCorrection? activeCorrection;
  final int positiveHistoryCount;
  final int negativeHistoryCount;
  final int wordingHistoryCount;
  final int evidenceHistoryCount;

  /// Once recorded for this archive-scoped target, ignore-forever remains in
  /// force even if a later correction supersedes that row.
  final bool isIgnoredForever;

  bool get allowsAdmission => !isIgnoredForever;
}

class ArchiveCorrectionPolicyLookup {
  const ArchiveCorrectionPolicyLookup(this._repository);

  final ArchiveCorrectionRepository _repository;

  Future<ArchiveCorrectionPolicy> forTarget({
    required String archiveScope,
    required String targetProofId,
    String targetProofFingerprint = '',
  }) async {
    final history = await _repository.historyForTarget(
      archiveScope: archiveScope,
      targetProofId: targetProofId,
      targetProofFingerprint: targetProofFingerprint,
    );
    final active = await _repository.activeForTarget(
      archiveScope: archiveScope,
      targetProofId: targetProofId,
      targetProofFingerprint: targetProofFingerprint,
    );

    var positive = 0;
    var negative = 0;
    var wording = 0;
    var evidence = 0;
    var ignoredForever = false;

    for (final correction in history) {
      switch (correction.choice) {
        case ArchiveCorrectionChoice.exactlyRight:
        case ArchiveCorrectionChoice.partlyRight:
          positive++;
        case ArchiveCorrectionChoice.wrong:
          negative++;
        case ArchiveCorrectionChoice.wrongWording:
          wording++;
        case ArchiveCorrectionChoice.wrongEvidence:
          evidence++;
        case ArchiveCorrectionChoice.ignoreForever:
          ignoredForever = true;
      }
    }

    return ArchiveCorrectionPolicy(
      activeCorrection: active,
      positiveHistoryCount: positive,
      negativeHistoryCount: negative,
      wordingHistoryCount: wording,
      evidenceHistoryCount: evidence,
      isIgnoredForever: ignoredForever,
    );
  }
}
