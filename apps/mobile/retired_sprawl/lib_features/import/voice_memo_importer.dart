import 'dart:io';

import 'package:archiveme_mobile/features/health/state_of_mind_reader.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Turns an `.m4a` shared from Voice Memos into a backdated journal entry.
abstract final class VoiceMemoImporter {
  VoiceMemoImporter._();

  static const captureSource = 'apple_voice_memo';

  static bool accepts(String path) {
    return path.toLowerCase().endsWith('.m4a');
  }

  static Future<JournalEntry?> importFile({
    required File audio,
    ConfirmedSpeechLocale? locale,
    DateTime? createdAt,
    Future<String?> Function(File audio, ConfirmedSpeechLocale locale)?
        transcribe,
  }) async {
    if (!accepts(audio.path) || !audio.existsSync()) return null;
    final spoken = transcribe ??
        ((file, chosen) => NativeSpeechTranscription.transcribeFile(
              file,
              locale: chosen,
            ));
    final chosen = locale;
    final transcript = chosen == null
        ? ''
        : ((await spoken(audio, chosen))?.trim() ?? '');
    final recordedAt = (createdAt ?? audio.lastModifiedSync()).toUtc();
    final entry = JournalEntry(
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
    return StateOfMindReader.attach(entry);
  }
}

/// Receives an `.m4a` the iOS document handler stored until Dart can save it.
abstract final class VoiceMemoImportInbox {
  VoiceMemoImportInbox._();

  static const MethodChannel channel = MethodChannel(
    'archive_me/voice_memo_import',
  );

  static Future<JournalEntry?> consume({
    Map<Object?, Object?>? pending,
    required Future<ConfirmedSpeechLocale?> Function() readLocale,
    required Future<void> Function(JournalEntry entry) save,
    Future<String?> Function(File audio, ConfirmedSpeechLocale locale)?
        transcribe,
  }) async {
    final payload = pending ?? await _take();
    if (payload == null) return null;
    final path = payload['path'];
    if (path is! String || !VoiceMemoImporter.accepts(path)) return null;
    final createdRaw = payload['createdAt'];
    final created =
        createdRaw is String ? DateTime.tryParse(createdRaw)?.toUtc() : null;
    final entry = await VoiceMemoImporter.importFile(
      audio: File(path),
      locale: await readLocale(),
      createdAt: created,
      transcribe: transcribe,
    );
    if (entry == null) return null;
    await save(entry);
    return entry;
  }

  static Future<Map<Object?, Object?>?> _take() async {
    if (kIsWeb || !Platform.isIOS) return null;
    try {
      return await channel.invokeMethod<Map<Object?, Object?>>('takePending');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
