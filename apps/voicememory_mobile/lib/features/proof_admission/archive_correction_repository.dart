import 'archive_correction.dart';

abstract interface class ArchiveCorrectionRepository {
  /// Saves a correction and supersedes the active correction for the same
  /// archive-scoped proof.
  Future<void> save(ArchiveCorrection correction);

  Future<List<ArchiveCorrection>> historyForArchive(String archiveScope);

  Future<List<ArchiveCorrection>> historyForTarget({
    required String archiveScope,
    required String targetProofId,
    String targetProofFingerprint = '',
  });

  Future<ArchiveCorrection?> activeForTarget({
    required String archiveScope,
    required String targetProofId,
    String targetProofFingerprint = '',
  });
}

class InMemoryArchiveCorrectionRepository
    implements ArchiveCorrectionRepository {
  final List<ArchiveCorrection> _corrections = [];

  @override
  Future<void> save(ArchiveCorrection correction) async {
    final existingIdIndex = _corrections.indexWhere(
      (candidate) => candidate.correctionId == correction.correctionId,
    );
    if (existingIdIndex >= 0) {
      _corrections.removeAt(existingIdIndex);
    }

    for (var index = 0; index < _corrections.length; index++) {
      final candidate = _corrections[index];
      if (!candidate.superseded &&
          _sameTarget(candidate, correction) &&
          candidate.correctionId != correction.correctionId) {
        _corrections[index] = candidate.copyWith(
          superseded: true,
          updatedAt: correction.updatedAt,
        );
      }
    }
    _corrections.add(correction);
  }

  @override
  Future<List<ArchiveCorrection>> historyForArchive(String archiveScope) async {
    final result =
        _corrections
            .where((correction) => correction.archiveScope == archiveScope)
            .toList()
          ..sort(_newestFirst);
    return List.unmodifiable(result);
  }

  @override
  Future<List<ArchiveCorrection>> historyForTarget({
    required String archiveScope,
    required String targetProofId,
    String targetProofFingerprint = '',
  }) async {
    final result =
        _corrections
            .where(
              (correction) =>
                  correction.archiveScope == archiveScope &&
                  _matchesTarget(
                    correction,
                    targetProofId,
                    targetProofFingerprint,
                  ),
            )
            .toList()
          ..sort(_newestFirst);
    return List.unmodifiable(result);
  }

  @override
  Future<ArchiveCorrection?> activeForTarget({
    required String archiveScope,
    required String targetProofId,
    String targetProofFingerprint = '',
  }) async {
    final history = await historyForTarget(
      archiveScope: archiveScope,
      targetProofId: targetProofId,
      targetProofFingerprint: targetProofFingerprint,
    );
    for (final correction in history) {
      if (!correction.superseded) return correction;
    }
    return null;
  }

  static bool _sameTarget(ArchiveCorrection first, ArchiveCorrection second) {
    if (first.archiveScope != second.archiveScope) return false;
    return _matchesTarget(
      first,
      second.targetProofId,
      second.targetProofFingerprint,
    );
  }

  static bool _matchesTarget(
    ArchiveCorrection correction,
    String targetProofId,
    String targetProofFingerprint,
  ) {
    final idMatches =
        targetProofId.isNotEmpty && correction.targetProofId == targetProofId;
    final fingerprintMatches =
        targetProofFingerprint.isNotEmpty &&
        correction.targetProofFingerprint == targetProofFingerprint;
    return idMatches || fingerprintMatches;
  }

  static int _newestFirst(ArchiveCorrection first, ArchiveCorrection second) {
    final updatedOrder = second.updatedAt.compareTo(first.updatedAt);
    if (updatedOrder != 0) return updatedOrder;
    final createdOrder = second.createdAt.compareTo(first.createdAt);
    if (createdOrder != 0) return createdOrder;
    return second.correctionId.compareTo(first.correctionId);
  }
}
