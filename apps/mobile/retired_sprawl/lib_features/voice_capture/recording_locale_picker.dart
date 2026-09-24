import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:flutter/widgets.dart';

/// The recording language shown in the picker, and what transcription receives.
class RecordingLocaleSelection {
  const RecordingLocaleSelection({
    this.locale,
    this.sherpaModelId,
    this.unsupportedMessage,
  });

  /// Confirmed only when the device locale is offered and supported on device.
  final ConfirmedSpeechLocale? locale;

  /// sherpa_onnx model id for [locale], when this build has that model.
  final String? sherpaModelId;

  /// Shown when the device locale cannot be transcribed on device.
  final String? unsupportedMessage;

  bool get canTranscribeOnDevice =>
      locale != null && unsupportedMessage == null;
}

/// Maps a language subtag to an on-device sherpa_onnx model, when one exists.
abstract final class SherpaOnnxLocaleModels {
  SherpaOnnxLocaleModels._();

  static const models = <String, String>{
    'en': 'vits-piper-en',
    'zh': 'vits-zh',
    'hi': 'vits-hi',
  };

  static String? modelFor(ConfirmedSpeechLocale locale) =>
      models[locale.primaryLanguageSubtag];
}

/// Picks the recording locale. The device locale is the default when it is
/// both offered and supported for on-device recognition.
abstract final class RecordingLocalePickerLogic {
  RecordingLocalePickerLogic._();

  static RecordingLocaleSelection selection({
    required Locale device,
    required List<OfferedSpeechLocale> offered,
    required Set<String> supportedOnDevice,
  }) {
    final match = _match(device, offered);
    if (match == null || !_supported(match.identifier, supportedOnDevice)) {
      final tag = device.toLanguageTag();
      return RecordingLocaleSelection(
        unsupportedMessage:
            '$tag is not supported for on-device transcription. Pick another language.',
      );
    }
    final locale = match.locale;
    return RecordingLocaleSelection(
      locale: locale,
      sherpaModelId: SherpaOnnxLocaleModels.modelFor(locale),
    );
  }

  static OfferedSpeechLocale? _match(
    Locale device,
    List<OfferedSpeechLocale> offered,
  ) {
    final tag = device.toLanguageTag().toLowerCase().replaceAll('_', '-');
    final language = device.languageCode.toLowerCase();
    OfferedSpeechLocale? languageOnly;
    for (final entry in offered) {
      final id = entry.identifier.toLowerCase();
      if (id == tag) return entry;
      if (id.split('-').first == language && languageOnly == null) {
        languageOnly = entry;
      }
    }
    return languageOnly;
  }

  static bool _supported(String identifier, Set<String> supportedOnDevice) {
    final wanted = identifier.toLowerCase();
    final language = wanted.split('-').first;
    for (final raw in supportedOnDevice) {
      final id = raw.toLowerCase().replaceAll('_', '-');
      if (id == wanted || id.split('-').first == language) return true;
    }
    return false;
  }
}

/// One text widget for a locale-sensitive sentence. The whole sentence is a
/// single string so RTL and CJK text are not split by concatenation.
class RecordingLocaleMessage extends StatelessWidget {
  const RecordingLocaleMessage({required this.selection, super.key});

  final RecordingLocaleSelection selection;

  @override
  Widget build(BuildContext context) {
    final message = selection.unsupportedMessage;
    if (message == null) {
      final locale = selection.locale;
      return Text(locale == null ? '' : locale.identifier);
    }
    return Text(message);
  }
}
