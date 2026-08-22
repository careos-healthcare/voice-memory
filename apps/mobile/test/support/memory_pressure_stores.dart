import 'dart:io';

import 'package:archiveme_mobile/billing/suggestion_attribution_event.dart';
import 'package:archiveme_mobile/billing/suggestion_attribution_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_micro_experiment_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_return_trigger_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

MobilePrefsStore _dummyPrefs() =>
    MobilePrefsStore(file: File('test/tmp/support/unused_prefs.json'));

/// In-memory micro-experiment store — keeps widget tests deterministic by
/// avoiding real file IO inside the fake-async test zone.
class MemoryExperimentStore extends PressureMicroExperimentStore {
  MemoryExperimentStore({bool accepted = false})
    : acceptedFlag = accepted,
      super(_dummyPrefs());

  bool acceptedFlag;

  @override
  Future<void> markAccepted({DateTime? now}) async => acceptedFlag = true;

  @override
  Future<DateTime?> acceptedAt() async =>
      acceptedFlag ? DateTime(2026, 6, 7) : null;
}

/// In-memory pressure check-in store for widget tests.
class MemoryPressureCheckInStore extends PressureCheckInStore {
  MemoryPressureCheckInStore([List<PressureCheckInRecord>? records])
    : records = records ?? [],
      super(_dummyPrefs());

  final List<PressureCheckInRecord> records;

  @override
  Future<void> save(PressureCheckInRecord record) async => records.add(record);

  @override
  Future<List<PressureCheckInRecord>> loadAll() async {
    final sorted = [...records]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<void> addContextTag({
    required String entryId,
    required String contextId,
    DateTime? now,
    bool treatAsNew = false,
  }) async {
    final index = records.indexWhere((r) => r.entryId == entryId);
    if (index >= 0) {
      final record = records[index];
      if (record.contextIds.contains(contextId)) return;
      records[index] = PressureCheckInRecord(
        entryId: record.entryId,
        createdAt: record.createdAt,
        optionId: record.optionId,
        contextIds: [...record.contextIds, contextId],
        fear: record.fear,
        stopCostNote: record.stopCostNote,
        choseToStop: record.choseToStop,
        transcript: record.transcript,
        treatAsNew: record.treatAsNew,
      );
      return;
    }
    records.add(
      PressureCheckInRecord(
        entryId: entryId,
        createdAt: now ?? DateTime(2026, 6, 10),
        optionId: PressureCheckInRecord.contextOnlyOptionId,
        contextIds: [contextId],
        treatAsNew: treatAsNew,
      ),
    );
  }
}

/// In-memory suggestion-to-Pro attribution store for widget tests.
class MemorySuggestionAttributionStore extends SuggestionAttributionStore {
  MemorySuggestionAttributionStore() : super(_dummyPrefs());

  final List<SuggestionAttributionEvent> recorded = [];

  @override
  Future<void> record(
    SuggestionAttributionEventType type, {
    String? suggestionId,
    DateTime? now,
  }) async {
    recorded.add(
      SuggestionAttributionEvent(
        type: type,
        suggestionId: suggestionId,
        at: now ?? DateTime(2026, 6, 10),
      ),
    );
  }

  @override
  Future<List<SuggestionAttributionEvent>> events() async => List.of(recorded);
}

/// In-memory return-trigger store for widget tests.
class MemoryReturnTriggerStore extends PressureReturnTriggerStore {
  MemoryReturnTriggerStore({bool accepted = false, bool dismissed = false})
    : acceptedFlag = accepted,
      dismissedFlag = dismissed,
      super(_dummyPrefs());

  bool acceptedFlag;
  bool dismissedFlag;

  @override
  Future<void> markAccepted({DateTime? now}) async => acceptedFlag = true;

  @override
  Future<void> markDismissed({DateTime? now}) async => dismissedFlag = true;

  @override
  Future<DateTime?> acceptedAt() async =>
      acceptedFlag ? DateTime(2026, 6, 8) : null;

  @override
  Future<DateTime?> dismissedAt() async =>
      dismissedFlag ? DateTime(2026, 6, 8) : null;
}