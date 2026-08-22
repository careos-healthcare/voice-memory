import 'package:archiveme_mobile/features/memory/keep_exact_details.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/treat_as_new.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_option.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_context.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Orchestrates saving a pressure check-in: writes the evidence-grade journal
/// entry to [JournalStore] and the structured record to [PressureCheckInStore].
class PressureCheckInService {
  PressureCheckInService({
    required this.journalStore,
    required this.store,
    this.engine = const PressureCheckInEngine(),
  });

  final JournalStore journalStore;
  final PressureCheckInStore store;
  final PressureCheckInEngine engine;

  /// first25 analytics source tag for pressure check-ins.
  static const first25Source = 'pressure_check_in';

  static PressureCheckInService instance() => PressureCheckInService(
    journalStore: AppServices.instance.journalStore,
    store: PressureCheckInStore.instance(),
  );

  Future<PressureCheckInSaveResult> save({
    required PressureCheckInOption option,
    List<PressureContext> contexts = const [],
    String? fear,
    String? stopCostNote,
    bool choseToStop = false,
    DateTime? now,
    String? entryId,
  }) async {
    final timestamp = now ?? DateTime.now();
    final id = entryId ?? 'pressure_${timestamp.microsecondsSinceEpoch}';

    final built = engine.build(
      entryId: id,
      option: option,
      now: timestamp,
      contexts: contexts,
      fear: fear,
      stopCostNote: stopCostNote,
      choseToStop: choseToStop,
    );

    // Snapshot the per-save memory choices before the journal save
    // consumes them, so the structured record carries the same metadata
    // as the entry it belongs to.
    final fresh =
        MemoryScopePolicy.scope == MemoryScope.off ||
        TreatAsNew.selectedForNextSave;
    final approved = !fresh && MemoryScopePolicy.connectApprovedForNextSave;
    final keepExact = KeepExactDetails.selectedForNextSave;
    await journalStore.save(built.entry, first25Source: first25Source);
    final record = (fresh || approved || keepExact)
        ? PressureCheckInRecord(
            entryId: built.record.entryId,
            createdAt: built.record.createdAt,
            optionId: built.record.optionId,
            contextIds: built.record.contextIds,
            fear: built.record.fear,
            stopCostNote: built.record.stopCostNote,
            choseToStop: built.record.choseToStop,
            transcript: built.record.transcript,
            treatAsNew: fresh,
            connectionApproved: approved,
            keepExactDetails: keepExact,
          )
        : built.record;
    await store.save(record);

    // First-win detection: was this the user's very first pressure moment?
    final all = await store.loadAll();
    final isFirst = all.length <= 1;

    return PressureCheckInSaveResult(
      entry: built.entry,
      record: record,
      isFirst: isFirst,
    );
  }
}

class PressureCheckInSaveResult {
  const PressureCheckInSaveResult({
    required this.entry,
    required this.record,
    this.isFirst = false,
  });

  final JournalEntry entry;
  final PressureCheckInRecord record;

  /// True when this save was the user's first pressure check-in.
  final bool isFirst;
}