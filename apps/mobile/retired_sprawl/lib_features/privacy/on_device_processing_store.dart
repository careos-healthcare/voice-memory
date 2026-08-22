import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// When enabled, raw audio and transcripts stay on-device.
///
/// Storage distinguishes three states, and the difference matters:
///
/// * key absent — the customer has not chosen, so [defaultEnabled] decides;
/// * `{'enabled': true}` / `{'enabled': false}` — an explicit choice, which
///   [defaultEnabled] must not override on any later app version.
abstract final class OnDeviceProcessingStore {
  OnDeviceProcessingStore._();

  static const prefsKey = 'on_device_processing_only_v1';

  /// Platform default for a customer who has not chosen either way.
  ///
  /// iOS keeps on-device-only on: `NativeSpeechTranscription` still has a
  /// local path there. Android has none — the Kotlin recognizer was removed
  /// and `NativeSpeechTranscription.blockedPlatforms` refuses the channel —
  /// so defaulting Android to on-device-only defaults Android to no
  /// transcription whatsoever. See `TranscriptionCapabilityPolicy` for the
  /// prompt that covers the remaining gap.
  static bool get defaultEnabled => defaultEnabledFor(platformName);

  /// [defaultEnabled] for an explicit platform, so callers and tests can
  /// reason about a platform they are not running on.
  static bool defaultEnabledFor(String platform) =>
      platform.trim().toLowerCase() != 'android';

  /// What an unreadable preference resolves to.
  ///
  /// Deliberately not [defaultEnabled]. Failing closed means blocking remote
  /// processing, and on Android the platform default is off — so reusing the
  /// default here would fail *open* on exactly the platform that changed.
  static const bool failClosedEnabled = true;

  /// Lets host-VM tests exercise per-platform behaviour without a device.
  @visibleForTesting
  static String? debugPlatformOverride;

  static String get platformName {
    final override = debugPlatformOverride;
    if (override != null) return override;
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }

  /// The customer's explicit choice, or null when they have not made one.
  static bool? _explicit;
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (!AppServices.isInitialized) {
      _loaded = true;
      return;
    }
    try {
      final raw = await AppServices.instance.prefs.readJsonMap(prefsKey);
      _explicit = raw?['enabled'] is bool ? raw!['enabled'] as bool : null;
    } on Object {
      // ignore: silent_catch_audit — an unreadable setting must not be read as
      // permission to upload, and the platform default is not safe here.
      _explicit = failClosedEnabled;
    }
    _loaded = true;
  }

  static bool get enabled => _explicit ?? defaultEnabled;

  /// Whether the customer has chosen, as opposed to inheriting a default.
  static bool get hasExplicitPreference => _explicit != null;

  static Future<void> setEnabled(bool value) async {
    _explicit = value;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {'enabled': value});
  }

  /// Clears the toggle because the customer granted a remote purpose in the
  /// consent flow, and only then.
  ///
  /// Separate from [setEnabled] so the call site reads as what it is. Clearing
  /// this is necessary but not sufficient for anything to be sent:
  /// `RemoteProcessingConsentGate` still requires a grant for the specific
  /// purpose, so this cannot permit an unconsented upload on its own.
  static Future<void> clearForGrantedRemoteConsent() => setEnabled(false);

  static Future<void> resetForTest() async {
    _explicit = null;
    _loaded = false;
    debugPlatformOverride = null;
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
    return await readExplicit() ?? OnDeviceProcessingStore.defaultEnabled;
  }

  /// The stored choice, or null when the key holds no boolean — the state a
  /// platform default is allowed to resolve.
  Future<bool?> readExplicit() async {
    final raw = await _prefs.readJsonMap(OnDeviceProcessingStore.prefsKey);
    if (raw?['enabled'] is bool) return raw!['enabled'] as bool;
    return null;
  }
}

/// User-facing copy for the on-device processing control.
abstract final class OnDeviceProcessingCopy {
  OnDeviceProcessingCopy._();

  static const title = 'Never send to server';

  /// States the consequence per capability rather than per platform.
  ///
  /// The previous wording ended "Remote analysis is never used", which was an
  /// unscoped absolute and, worse, stated the outcome for the wrong platform.
  /// This mode is not uniformly degraded: iOS keeps a local path through
  /// `IosNativeSpeechTranscription` (`SFSpeechRecognizer`), so the transcript
  /// still arrives, while Android is on
  /// `NativeSpeechTranscription.blockedPlatforms` and gets no transcript at
  /// all. Naming iOS as the limited case would have inverted that.
  ///
  /// No platform is named, matching `OnDeviceArchitectureCopy` and
  /// `TrustStatusFooterCopy`: the answer changes per OS release, and copy that
  /// hard-codes today's split goes stale silently. "Where the system provides a
  /// speech recogniser" is the same condition stated as a capability.
  static const subtitle =
      'When on, voice processing stays on this device even when local '
      'confidence is low. Where the system provides a speech recogniser you '
      'still get a transcript; where it does not, the recording stays '
      'untranscribed instead of being sent.';
  static const body =
      'Raw audio never leaves this device unless you turn this off and grant '
      'remote processing consent separately.';
}
