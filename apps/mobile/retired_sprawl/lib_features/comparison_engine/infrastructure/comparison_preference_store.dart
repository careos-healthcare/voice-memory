import 'package:archiveme_mobile/features/comparison_engine/presentation/controllers/post_save_comparison_controller.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

class ComparisonPreferenceStore implements PreferenceStore {
  ComparisonPreferenceStore(this._prefs);

  static const _dismissedKey = 'comparison_pro_trail_prompt_dismissed';

  final MobilePrefsStore _prefs;
  bool _loaded = false;
  bool _dismissed = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _dismissed = await _prefs.readBool(_dismissedKey) ?? false;
    _loaded = true;
  }

  @override
  bool getHasDismissedProPrompt() {
    return _dismissed;
  }

  @override
  Future<void> setHasDismissedProPrompt(bool value) async {
    _dismissed = value;
    _loaded = true;
    await _prefs.writeBool(_dismissedKey, value);
  }
}