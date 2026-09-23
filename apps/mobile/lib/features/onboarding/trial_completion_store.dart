import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Remembers whether the 30-second trial voice entry has finished.
abstract interface class TrialCompletionStore {
  Future<bool> hasCompletedTrial();

  Future<void> markTrialCompleted();
}

/// In-memory stand-in for tests and launches before prefs exist.
class MemoryTrialCompletionStore implements TrialCompletionStore {
  bool completed = false;

  @override
  Future<bool> hasCompletedTrial() async => completed;

  @override
  Future<void> markTrialCompleted() async {
    completed = true;
  }
}

/// Persists `has_completed_trial` in local app preferences.
class PrefsTrialCompletionStore implements TrialCompletionStore {
  PrefsTrialCompletionStore(this.prefs);

  final MobilePrefsStore prefs;

  static const key = 'has_completed_trial';

  @override
  Future<bool> hasCompletedTrial() async => (await prefs.readBool(key)) ?? false;

  @override
  Future<void> markTrialCompleted() => prefs.writeBool(key, true);
}
