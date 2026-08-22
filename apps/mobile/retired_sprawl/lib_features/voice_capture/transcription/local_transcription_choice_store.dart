import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// What the customer answered when told local transcription is unavailable.
enum LocalTranscriptionChoice {
  /// They have not been asked, or the record cannot be read.
  unset,

  /// Send the audio for remote transcription.
  remoteTranscription,

  /// Save the recording with its audio and no transcript.
  noTranscription,
}

/// The customer's standing answer to the local-transcription gap.
///
/// Persisted because the answer is theirs to give once. "No transcription" is a
/// real choice, so a recorded `noTranscription` has to stop the prompt from
/// coming back rather than becoming a weekly nag.
class LocalTranscriptionChoiceStore {
  LocalTranscriptionChoiceStore(this._prefs);

  static const String prefsKey = 'local_transcription_unavailable_choice_v1';

  static const String _remoteToken = 'remote_transcription';
  static const String _noneToken = 'no_transcription';

  final MobilePrefsStore _prefs;

  Future<LocalTranscriptionChoice> read() async {
    try {
      final raw = await _prefs.readJsonMap(prefsKey);
      return switch (raw?['choice']) {
        _remoteToken => LocalTranscriptionChoice.remoteTranscription,
        _noneToken => LocalTranscriptionChoice.noTranscription,
        _ => LocalTranscriptionChoice.unset,
      };
    } on Object {
      // ignore: silent_catch_audit — an unreadable answer is not an answer.
      // Reading it as `remoteTranscription` would upload on a storage error.
      return LocalTranscriptionChoice.unset;
    }
  }

  Future<void> record(LocalTranscriptionChoice choice) async {
    final token = switch (choice) {
      LocalTranscriptionChoice.remoteTranscription => _remoteToken,
      LocalTranscriptionChoice.noTranscription => _noneToken,
      LocalTranscriptionChoice.unset => null,
    };
    if (token == null) return;
    await _prefs.writeJsonMap(prefsKey, {
      'choice': token,
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
