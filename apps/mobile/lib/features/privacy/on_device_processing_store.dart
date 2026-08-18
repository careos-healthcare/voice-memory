import 'dart:async';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// When enabled (default), raw audio and transcripts stay on-device.
abstract final class OnDeviceProcessingStore {
  OnDeviceProcessingStore._();

  static const prefsKey = 'on_device_processing_only_v1';

  /// Matches current architecture: remote processing is opt-in, on-device default.
  static const bool defaultEnabled = true;

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

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {'enabled': value});
  }

  static Future<void> resetForTest() async {
    _enabled = defaultEnabled;
    _loaded = false;
    if (AppServices.isInitialized) {
      await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
    }
  }
}

class OnDeviceProcessingStoreForTest {
  OnDeviceProcessingStoreForTest(this._prefs);

  final MobilePrefsStore _prefs;

  Future<void> setEnabled(bool value) async {
    await _prefs.writeJsonMap(OnDeviceProcessingStore.prefsKey, {
      'enabled': value,
    });
  }

  Future<bool> readEnabled() async {
    final raw = await _prefs.readJsonMap(OnDeviceProcessingStore.prefsKey);
    if (raw?['enabled'] is bool) return raw!['enabled'] as bool;
    return OnDeviceProcessingStore.defaultEnabled;
  }
}

/// User-facing copy for the on-device processing control.
abstract final class OnDeviceProcessingCopy {
  OnDeviceProcessingCopy._();

  static const title = 'Process everything on-device';
  static const subtitle =
      'When on, raw audio and transcripts are never sent for remote processing. '
      'Some cloud-assisted modes may be limited.';
  static const body =
      'Raw audio never leaves this device unless you turn this off and grant '
      'remote processing consent separately.';
}
