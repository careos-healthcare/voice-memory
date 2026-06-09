import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/journal_store.dart';
import 'pressure_check_in_engine.dart';
import 'pressure_check_in_option.dart';
import 'pressure_check_in_record.dart';
import 'pressure_check_in_store.dart';
import 'pressure_context.dart';

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

    await journalStore.save(built.entry, first25Source: first25Source);
    await store.save(built.record);

    // First-win detection: was this the user's very first pressure moment?
    final all = await store.loadAll();
    final isFirst = all.length <= 1;

    return PressureCheckInSaveResult(
      entry: built.entry,
      record: built.record,
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
