import 'dart:io';

import 'package:archiveme_mobile/features/import/services/shared_media_receiver.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/sync/ulid.dart';

/// Transcribes a shared audio file and builds a backdated journal entry.
abstract final class SharedAudioBacklogImport {
  SharedAudioBacklogImport._();

  static const captureSource = 'apple_voice_memo';

  static Future<JournalEntry?> importFile({
    required File audio,
    ConfirmedSpeechLocale? locale,
    DateTime? createdAt,
    Future<String?> Function(String path)? readCreationDate,
    Future<String?> Function(File audio, ConfirmedSpeechLocale locale)?
    transcribe,
  }) async {
    if (!SharedMediaReceiver.accepts(audio.path) || !audio.existsSync()) {
      return null;
    }
    final recordedAt =
        createdAt?.toUtc() ??
        await SharedMediaReceiver.originalRecordingDate(
          audio,
          readCreationDate: readCreationDate,
        );
    if (recordedAt == null) return null;
    final spoken =
        transcribe ??
        ((file, chosen) => NativeSpeechTranscription.transcribeFile(
          file,
          locale: chosen,
        ));
    final transcript = locale == null
        ? ''
        : ((await spoken(audio, locale))?.trim() ?? '');
    return JournalEntry(
      id: generateUlid(),
      createdAt: recordedAt,
      updatedAt: recordedAt,
      transcript: transcript,
      durationSeconds: 1,
      localAudioPath: audio.path,
      captureSource: captureSource,
      reflection: const Reflection(
        mood: '',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
  }
}
