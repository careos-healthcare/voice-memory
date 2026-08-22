import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:meta/meta.dart';

/// When enabled, SQLCipher unlock requires Face ID / Touch ID / device passcode.
abstract final class DatabaseBiometricGateStore {
  DatabaseBiometricGateStore._();

  static const prefsKey = 'database_biometric_gate_v1';
  static const defaultEnabled = true;

  static bool _enabled = defaultEnabled;
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (!AppServices.isInitialized) {
      _loaded = true;
      return;
    }
    final raw = await AppServices.instance.prefs.readJsonMap(prefsKey);
    _enabled = raw?['enabled'] is bool ? raw!['enabled'] as bool : defaultEnabled;
    _loaded = true;
  }

  static bool get enabled => _enabled;

  static Future<bool> isEnabled() async {
    await ensureLoaded();
    return _enabled;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {'enabled': value});
  }

  static Future<void> resetForTest() async {
    _enabled = defaultEnabled;
    _loaded = false;
  }

  @visibleForTesting
  static void seedForTest({required bool enabled, MobilePrefsStore? prefs}) {
    _enabled = enabled;
    _loaded = true;
    if (prefs != null) {
      prefs.writeJsonMap(prefsKey, {'enabled': enabled});
    }
  }
}
