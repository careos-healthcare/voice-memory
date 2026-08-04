import '../../../../models/journal_entry.dart';
import '../../../journal/domain/interceptors/journal_save_interceptor.dart';
import '../../repositories/curiosity_loop_repository.dart';

/// Seeds curiosity loop memory-recall state after verified biomarker processing.
class CuriosityLoopTriggerInterceptor implements JournalSaveInterceptor {
  CuriosityLoopTriggerInterceptor({
    this._repository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CuriosityLoopRepository? _repository;
  final DateTime Function() _clock;

  CuriosityLoopRepository get _resolvedRepository =>
      _repository ?? LocalCuriosityLoopRepository.instance();

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    if (!_hasValidBiomarkers(entry)) return;

    final existing = await _resolvedRepository.fetchPendingMemoryRecallSeed();
    if (existing != null) return;

    await _resolvedRepository.seedMemoryRecallCheck(
      sourceEntryId: entry.id,
      seededAt: _clock().toUtc(),
    );
  }

  static bool _hasValidBiomarkers(JournalEntry entry) {
    final biomarkers = entry.biomarkers;
    if (biomarkers == null) return false;
    if (entry.id.trim().isEmpty) return false;
    if (entry.transcript.trim().isEmpty) return false;

    return _isValidScore(biomarkers.lexicalDiversity) &&
        _isValidScore(biomarkers.cohesionDrift) &&
        _isValidScore(biomarkers.emotionalVolatility);
  }

  static bool _isValidScore(double score) {
    return !score.isNaN && !score.isInfinite && score >= 0 && score <= 1;
  }
}
