import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';

/// Why local transcription cannot run on this device, when it cannot.
enum LocalTranscriptionUnavailableReason {
  /// This platform has no local recogniser this app can drive.
  ///
  /// Android since the Kotlin recogniser was deleted:
  /// `NativeSpeechTranscription.blockedPlatforms` refuses the channel and
  /// `isSupported` returns false ahead of any test override.
  platformUnsupported,

  /// The customer has not said which language they speak into the app.
  ///
  /// Not a device fault and not a permanent one: the recogniser is there, it
  /// just has not been told what to listen for. Kept separate from
  /// [localeUnsupported] because the two need different questions — this one is
  /// answered by picking a language, not by deciding whether to upload audio.
  /// It is checked first, because without a language there is nothing to ask
  /// the recogniser about.
  speechLanguageUnconfirmed,

  /// The platform recogniser exists but not for the language being spoken.
  ///
  /// iOS reports this per locale through `supportsOnDeviceRecognition`.
  localeUnsupported,

  /// The bundled offline model this app would use is not in the build.
  ///
  /// `WhisperModelContract.defaultAssetPath` is loaded from the asset bundle,
  /// and `pubspec.yaml` bundles no `assets/models/` entry, so
  /// `OnnxWhisperSpeechToText.tryCreate` resolves null in shipped builds.
  offlineModelMissing,
}

/// Whether local transcription can produce text for a recording right now.
class LocalTranscriptionSupport {
  const LocalTranscriptionSupport.available()
    : isAvailable = true,
      reason = null;

  const LocalTranscriptionSupport.unavailable(
    LocalTranscriptionUnavailableReason this.reason,
  ) : isAvailable = false;

  final bool isAvailable;
  final LocalTranscriptionUnavailableReason? reason;
}

/// The capability seam for local transcription.
///
/// This answers a question about the device, not about the network. A dropped
/// connection is not a capability gap and must not reach here — see
/// `TranscriptionCapabilityPolicy`.
abstract interface class LocalTranscriptionAvailability {
  Future<LocalTranscriptionSupport> check();
}

/// The per-locale iOS check.
///
/// Per-locale because that is what `SFSpeechRecognizer` actually reports:
/// `supportsOnDeviceRecognition` is a property of a recogniser built for one
/// language, so there is no device-wide answer to give.
abstract interface class IosOnDeviceRecognitionProbe {
  /// Whether `SFSpeechRecognizer.supportsOnDeviceRecognition` is true for
  /// [locale] on this device.
  ///
  /// Throwing is a valid answer meaning "could not find out", including the
  /// `MissingPluginException` raised on a build whose native side does not
  /// implement the method yet.
  Future<bool> supportsOnDeviceRecognition(ConfirmedSpeechLocale locale);
}

/// The real probe: asks the native speech channel.
///
/// NOTE: the Swift handler currently implements only `transcribeFile` and
/// returns `FlutterMethodNotImplemented` for anything else, so on today's iOS
/// build this throws and availability resolves to "available" — the same answer
/// as before, and never a manufactured prompt. Once the reported
/// `supportsOnDeviceRecognition` case is added to
/// `IosNativeSpeechTranscriptionHandler`, this starts telling the truth
/// with no Dart change.
class ChannelIosOnDeviceRecognitionProbe implements IosOnDeviceRecognitionProbe {
  const ChannelIosOnDeviceRecognitionProbe();

  @override
  Future<bool> supportsOnDeviceRecognition(ConfirmedSpeechLocale locale) {
    return NativeSpeechTranscription.platform.supportsOnDeviceRecognition(
      locale: locale,
    );
  }
}

/// Availability as this build can measure it.
///
/// Android is unconditionally unavailable. On a platform that has a recogniser,
/// the confirmed language is checked before the device is: [confirmedLocale] is
/// required rather than defaulted precisely because the version of this class
/// that took no locale at all reported iOS "available" on a device that could
/// never produce a transcript, and `TranscriptionCapabilityPolicy` believed it.
///
/// A probe that throws still resolves to available. A broken probe is absence
/// of evidence, and reading it as a capability gap would put a prompt in front
/// of someone whose device works and push them toward uploading audio to
/// dismiss it.
class PlatformLocalTranscriptionAvailability
    implements LocalTranscriptionAvailability {
  const PlatformLocalTranscriptionAvailability({
    required SpeechLocaleReader confirmedLocale,
    IosOnDeviceRecognitionProbe iosProbe =
        const ChannelIosOnDeviceRecognitionProbe(),
  }) : _confirmedLocale = confirmedLocale,
       _iosProbe = iosProbe;

  final SpeechLocaleReader _confirmedLocale;
  final IosOnDeviceRecognitionProbe _iosProbe;

  @override
  Future<LocalTranscriptionSupport> check() async {
    if (!NativeSpeechTranscription.isSupported) {
      return const LocalTranscriptionSupport.unavailable(
        LocalTranscriptionUnavailableReason.platformUnsupported,
      );
    }

    final locale = await _readConfirmedLocale();
    if (locale == null) {
      return const LocalTranscriptionSupport.unavailable(
        LocalTranscriptionUnavailableReason.speechLanguageUnconfirmed,
      );
    }

    try {
      final supported = await _iosProbe.supportsOnDeviceRecognition(locale);
      return supported
          ? const LocalTranscriptionSupport.available()
          : const LocalTranscriptionSupport.unavailable(
              LocalTranscriptionUnavailableReason.localeUnsupported,
            );
    } on Object {
      // ignore: silent_catch_audit — a probe that fails to answer is not
      // evidence of a capability gap, and must not raise a privacy prompt.
      return const LocalTranscriptionSupport.available();
    }
  }

  Future<ConfirmedSpeechLocale?> _readConfirmedLocale() async {
    try {
      return await _confirmedLocale();
    } on Object {
      // ignore: silent_catch_audit — an unreadable preference is not a
      // confirmed language. Falling back to the device locale here is the one
      // thing this whole type exists to prevent.
      return null;
    }
  }
}

/// Fixed answer for tests and for platforms measured elsewhere.
class StaticLocalTranscriptionAvailability
    implements LocalTranscriptionAvailability {
  const StaticLocalTranscriptionAvailability(this._support);

  const StaticLocalTranscriptionAvailability.available()
    : _support = const LocalTranscriptionSupport.available();

  StaticLocalTranscriptionAvailability.unavailable(
    LocalTranscriptionUnavailableReason reason,
  ) : _support = LocalTranscriptionSupport.unavailable(reason);

  final LocalTranscriptionSupport _support;

  @override
  Future<LocalTranscriptionSupport> check() async => _support;
}
