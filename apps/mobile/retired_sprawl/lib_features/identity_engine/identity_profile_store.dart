import 'package:archiveme_mobile/features/identity_engine/identity_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local persistence for identity profile (future backend sync).
class IdentityProfileStore {
  IdentityProfileStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'identityProfile';

  Future<IdentityProfile?> load() async {
    final raw = await _prefs.readJsonMap(_key);
    if (raw == null) return null;
    return IdentityProfile.fromJson(raw);
  }

  Future<void> save(IdentityProfile profile) async {
    await _prefs.writeJsonMap(_key, profile.toJson());
  }
}