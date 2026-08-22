import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_loop_repository.dart';

/// Applies pending clinical memory-recall flags to the next curiosity hook.
class CuriosityMemoryRecallHookEnricher {
  CuriosityMemoryRecallHookEnricher({this._repository});

  final CuriosityLoopRepository? _repository;

  CuriosityLoopRepository get _resolvedRepository =>
      _repository ?? LocalCuriosityLoopRepository.instance();

  Future<CuriosityHook> applyPendingSeed(CuriosityHook hook) async {
    final seed = await _resolvedRepository.fetchPendingMemoryRecallSeed();
    if (seed == null) return hook;
    if (seed.sourceEntryId == hook.entryId) return hook;

    await _resolvedRepository.clearPendingMemoryRecallSeed();
    return hook.copyWith(
      sourceEntryId: seed.sourceEntryId,
      isMemoryRecallCheck: true,
    );
  }
}