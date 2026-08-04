import '../../storage/mobile_prefs_store.dart';
import 'identity_models.dart';

/// Local persistence for identity profile (future backend sync).
class IdentityProfileStore {
  IdentityProfileStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'identityProfile';

  Future<IdentityProfile?> load() async {
    try {
      final raw = await _prefs.readJsonMap(_key);
      if (raw == null) return null;
      return IdentityProfile.fromJson(raw);
    } on Object {
      return null;
    }
  }

  Future<void> save(IdentityProfile profile) async {
    await _prefs.writeJsonMap(_key, profile.toJson());
  }
}
