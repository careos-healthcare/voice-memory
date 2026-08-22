import 'package:archiveme_mobile/features/acquisition/acquisition_intent_model.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Stores onboarding acquisition intent for analytics and light prompt tuning.
class AcquisitionIntentStore {
  AcquisitionIntentStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'acquisitionIntent';

  static AcquisitionIntentStore instance() =>
      AcquisitionIntentStore(AppServices.instance.prefs);

  Future<AcquisitionIntent?> load() async {
    final raw = await _prefs.readMap(_key);
    final id = raw?['intent'] as String?;
    if (id == null) return null;
    return AcquisitionIntent.values.firstWhere(
      (e) => e.id == id,
      orElse: () => AcquisitionIntent.notSureYet,
    );
  }

  Future<DateTime?> selectedAt() async {
    final raw = await _prefs.readMap(_key);
    return DateTime.tryParse(raw?['selectedAt'] as String? ?? '');
  }

  Future<void> save(AcquisitionIntent intent) async {
    await _prefs.writeMap(_key, {
      'intent': intent.id,
      'selectedAt': DateTime.now().toUtc().toIso8601String(),
    });
    ActivationTracker.trackOnboardingIntentSelected();
  }

  Future<String> firstRecordingPrompt() async {
    final intent = await load();
    return intent?.firstPrompt ?? AcquisitionIntent.notSureYet.firstPrompt;
  }
}