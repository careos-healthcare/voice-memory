import '../../storage/mobile_prefs_store.dart';
import 'archive_evolution_models.dart';

class ArchiveEvolutionStore {
  ArchiveEvolutionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _stateKey = 'archiveEvolutionState';

  Future<ArchiveEvolutionState> read() async {
    final raw = await _prefs.readJsonMap(_stateKey);
    if (raw == null || raw.isEmpty) return const ArchiveEvolutionState();

    return ArchiveEvolutionState(
      activeEvolution: ArchiveEvolution.fromJson(
        _mapOrNull(raw['activeEvolution']),
      ),
      pendingEvolutionEvent: PendingEvolutionNotification.fromJson(
        _mapOrNull(raw['pendingEvolutionEvent']),
      ),
      lastDismissedEvolutionId: raw['lastDismissedEvolutionId']?.toString(),
      lastEntryIdWhenEvolved: raw['lastEntryIdWhenEvolved']?.toString(),
      lastArchiveUpdateAt: DateTime.tryParse(
        raw['lastArchiveUpdateAt']?.toString() ?? '',
      ),
    );
  }

  Future<void> writeActiveEvolution({
    required ArchiveEvolution evolution,
    required String lastEntryId,
  }) async {
    final prior = await read();
    await _write(
      ArchiveEvolutionState(
        activeEvolution: evolution,
        pendingEvolutionEvent: prior.pendingEvolutionEvent,
        lastDismissedEvolutionId: prior.lastDismissedEvolutionId,
        lastEntryIdWhenEvolved: lastEntryId,
        lastArchiveUpdateAt: DateTime.now(),
      ),
    );
  }

  Future<void> setPendingEvolutionEvent(ArchiveEvolution evolution) async {
    final prior = await read();
    await _write(
      ArchiveEvolutionState(
        activeEvolution: prior.activeEvolution,
        pendingEvolutionEvent: PendingEvolutionNotification(
          evolution: evolution,
          recordedAt: DateTime.now(),
        ),
        lastDismissedEvolutionId: prior.lastDismissedEvolutionId,
        lastEntryIdWhenEvolved: prior.lastEntryIdWhenEvolved,
        lastArchiveUpdateAt: DateTime.now(),
      ),
    );
  }

  Future<void> clearPendingEvolutionEvent() async {
    final prior = await read();
    await _write(
      ArchiveEvolutionState(
        activeEvolution: prior.activeEvolution,
        pendingEvolutionEvent: null,
        lastDismissedEvolutionId: prior.lastDismissedEvolutionId,
        lastEntryIdWhenEvolved: prior.lastEntryIdWhenEvolved,
        lastArchiveUpdateAt: prior.lastArchiveUpdateAt,
      ),
    );
  }

  Future<void> dismiss(ArchiveEvolution evolution) async {
    final prior = await read();
    await _write(
      ArchiveEvolutionState(
        activeEvolution: null,
        pendingEvolutionEvent: prior.pendingEvolutionEvent,
        lastDismissedEvolutionId: evolution.id,
        lastEntryIdWhenEvolved: prior.lastEntryIdWhenEvolved,
        lastArchiveUpdateAt: prior.lastArchiveUpdateAt,
      ),
    );
  }

  Future<void> touchArchiveUpdate() async {
    final prior = await read();
    await _write(
      ArchiveEvolutionState(
        activeEvolution: prior.activeEvolution,
        pendingEvolutionEvent: prior.pendingEvolutionEvent,
        lastDismissedEvolutionId: prior.lastDismissedEvolutionId,
        lastEntryIdWhenEvolved: prior.lastEntryIdWhenEvolved,
        lastArchiveUpdateAt: DateTime.now(),
      ),
    );
  }

  Future<void> _write(ArchiveEvolutionState state) async {
    await _prefs.writeJsonMap(_stateKey, {
      if (state.activeEvolution != null)
        'activeEvolution': state.activeEvolution!.toJson(),
      if (state.pendingEvolutionEvent != null)
        'pendingEvolutionEvent': state.pendingEvolutionEvent!.toJson(),
      if (state.lastDismissedEvolutionId != null)
        'lastDismissedEvolutionId': state.lastDismissedEvolutionId,
      if (state.lastEntryIdWhenEvolved != null)
        'lastEntryIdWhenEvolved': state.lastEntryIdWhenEvolved,
      if (state.lastArchiveUpdateAt != null)
        'lastArchiveUpdateAt': state.lastArchiveUpdateAt!
            .toUtc()
            .toIso8601String(),
    });
  }

  static Map<String, dynamic>? _mapOrNull(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}
