import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Locally revoked consent token IDs — blocks verification after revoke.
abstract final class ConsentRevocationStore {
  ConsentRevocationStore._();

  static const prefsKey = 'consent_revoked_tokens_v1';

  static final Set<String> _revoked = <String>{};
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (!AppServices.isInitialized) {
      _loaded = true;
      return;
    }
    final raw = await AppServices.instance.prefs.readJsonMap(prefsKey);
    final ids = raw?['tokenIds'];
    if (ids is List) {
      _revoked
        ..clear()
        ..addAll(ids.whereType<String>());
    }
    _loaded = true;
  }

  static bool isRevoked(String tokenId) => _revoked.contains(tokenId);

  static Future<void> revoke(String tokenId) async {
    _revoked.add(tokenId);
    await _persist();
  }

  static Future<void> _persist() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {
      'tokenIds': _revoked.toList(),
    });
  }

  static Future<void> resetForTest() async {
    _revoked.clear();
    _loaded = false;
    if (AppServices.isInitialized) {
      await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
    }
  }
}

/// Test helper without AppServices.
class ConsentRevocationStoreForTest {
  ConsentRevocationStoreForTest(this._prefs);

  final MobilePrefsStore _prefs;

  Future<void> revoke(String tokenId) async {
    final raw = await _prefs.readJsonMap(ConsentRevocationStore.prefsKey) ?? {};
    final ids = {...?((raw['tokenIds'] as List?)?.whereType<String>())};
    ids.add(tokenId);
    await _prefs.writeJsonMap(ConsentRevocationStore.prefsKey, {
      'tokenIds': ids.toList(),
    });
  }

  Future<bool> isRevoked(String tokenId) async {
    final raw = await _prefs.readJsonMap(ConsentRevocationStore.prefsKey);
    final ids = raw?['tokenIds'];
    if (ids is! List) return false;
    return ids.contains(tokenId);
  }
}
