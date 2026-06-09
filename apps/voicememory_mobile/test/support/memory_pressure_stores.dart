import 'dart:io';

import 'package:voicememory_mobile/features/pressure_retention/pressure_micro_experiment_store.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_return_trigger_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

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
