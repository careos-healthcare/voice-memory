import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../storage/mobile_prefs_store.dart';

/// Whether this device can run on-device transcription at all.
///
/// Unsupported devices must never be shown the local option, so this is a hard
/// platform capability answer rather than a hint the UI has to qualify.
abstract interface class OnDeviceTranscriptionSupport {
  Future<bool> isSupported();
}

final class PlatformOnDeviceTranscriptionSupport
    implements OnDeviceTranscriptionSupport {
  const PlatformOnDeviceTranscriptionSupport();

  @override
  Future<bool> isSupported() async =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}

final class FixedOnDeviceTranscriptionSupport
    implements OnDeviceTranscriptionSupport {
  const FixedOnDeviceTranscriptionSupport(this.supported);

  final bool supported;

  @override
  Future<bool> isSupported() async => supported;
}

/// The user's standing choice to always transcribe online instead of locally.
abstract interface class OnlineOnlyTranscriptionPreference {
  Future<bool> prefersOnlineOnly();
}

final class OnlineOnlyTranscriptionPreferenceStore
    implements OnlineOnlyTranscriptionPreference {
  OnlineOnlyTranscriptionPreferenceStore(this._prefs);

  static const storageKey = 'transcriptionPrefersOnlineOnlyV1';

  final MobilePrefsStore Function() _prefs;

  @override
  Future<bool> prefersOnlineOnly() async =>
      await _prefs().readBool(storageKey) ?? false;

  Future<void> setPrefersOnlineOnly(bool value) =>
      _prefs().writeBool(storageKey, value);
}

final class FixedOnlineOnlyTranscriptionPreference
    implements OnlineOnlyTranscriptionPreference {
  const FixedOnlineOnlyTranscriptionPreference(this.onlineOnly);

  final bool onlineOnly;

  @override
  Future<bool> prefersOnlineOnly() async => onlineOnly;
}
