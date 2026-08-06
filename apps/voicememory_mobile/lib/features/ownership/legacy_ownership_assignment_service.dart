import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';

/// Neutral recovery namespace for unowned legacy entries awaiting assignment.
abstract final class LegacyOwnershipRecovery {
  LegacyOwnershipRecovery._();

  static const recoveryNamespaceKey = 'legacy_ownership_recovery_v1';
  static const assignmentStateKey = 'legacy_ownership_assignment_v1';
  static const quarantineCompleteKey = 'legacy_ownership_quarantine_v1';
}

/// One-time assignment of unowned legacy entries to the active account.
class LegacyOwnershipAssignmentService {
  LegacyOwnershipAssignmentService({
    required JournalStore recoveryJournal,
    required JournalStore activeJournal,
    required MobilePrefsStore prefs,
  }) : _recoveryJournal = recoveryJournal,
       _activeJournal = activeJournal,
       _prefs = prefs;

  final JournalStore _recoveryJournal;
  final JournalStore _activeJournal;
  final MobilePrefsStore _prefs;

  Future<int> countAwaitingAssignment() async {
    final entries = await _recoveryJournal.loadAllIncludingTombstones();
    return entries.where((e) => e.ownerKey == null || e.ownerKey!.isEmpty).length;
  }

  /// Idempotent import — each entry ID can move to [destinationOwnerKey] once.
  Future<LegacyOwnershipAssignmentResult> assignAllToAccount(
    String destinationOwnerKey,
  ) async {
    final state = await _prefs.readJsonMap(LegacyOwnershipRecovery.assignmentStateKey) ?? {};
    final assignedIds = (state['assignedIds'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toSet();

    final pending = await _recoveryJournal.loadAllIncludingTombstones();
    var imported = 0;
    for (final entry in pending) {
      if (assignedIds.contains(entry.id)) continue;
      final stamped = entry.copyWith(ownerKey: destinationOwnerKey);
      await _activeJournal.save(stamped);
      assignedIds.add(entry.id);
      imported++;
    }

    state['assignedIds'] = assignedIds.toList();
    state['lastAssignedOwner'] = destinationOwnerKey;
    state['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    if (pending.every((e) => assignedIds.contains(e.id))) {
      state['status'] = 'completed';
      state['completedAt'] = DateTime.now().toUtc().toIso8601String();
      await _prefs.writeJsonMap(LegacyOwnershipRecovery.quarantineCompleteKey, {
        'completedAt': state['completedAt'],
        'note': 'Recovery journal eligible for secure removal after operator audit.',
      });
    } else {
      state['status'] = 'in_progress';
    }
    await _prefs.writeJsonMap(LegacyOwnershipRecovery.assignmentStateKey, state);

    return LegacyOwnershipAssignmentResult(
      importedCount: imported,
      awaitingCount: pending.length - assignedIds.length,
      completed: state['status'] == 'completed',
    );
  }
}

class LegacyOwnershipAssignmentResult {
  const LegacyOwnershipAssignmentResult({
    required this.importedCount,
    required this.awaitingCount,
    required this.completed,
  });

  final int importedCount;
  final int awaitingCount;
  final bool completed;
}