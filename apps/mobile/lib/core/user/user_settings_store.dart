import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/core/user/user_settings.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists global user settings (thematic lens, future prefs).
class UserSettingsStore {
  UserSettingsStore(this._prefs);

  static const prefsKey = 'user_settings_v1';

  final MobilePrefsStore _prefs;

  UserSettings _cached = const UserSettings();
  bool _loaded = false;

  UserSettings get current => _cached;

  Future<UserSettings> load() async {
    if (_loaded) return _cached;
    final raw = await _prefs.readJsonMap(prefsKey);
    _cached = UserSettings.fromJson(raw);
    _loaded = true;
    return _cached;
  }

  Future<UserSettings> save(UserSettings settings) async {
    _cached = settings;
    _loaded = true;
    await _prefs.writeJsonMap(prefsKey, settings.toJson());
    return settings;
  }

  Future<UserSettings> setActiveLens(LifeStageLens? lens) async {
    if (lens == null || lens == LifeStageLens.defaultLens) {
      return save(const UserSettings());
    }
    return save(UserSettings(activeLens: lens));
  }
}