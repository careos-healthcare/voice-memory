import 'dart:io';

import 'package:archiveme_mobile/features/import/services/backlog_import_service.dart';
import 'package:archiveme_mobile/features/import/services/shared_media_receiver.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Turns shared Voice Memos audio into a backdated journal entry.
abstract final class VoiceMemoImporter {
  VoiceMemoImporter._();

  static const captureSource = SharedAudioBacklogImport.captureSource;

  static bool accepts(String path) => SharedMediaReceiver.accepts(path);

  static Future<JournalEntry?> importFile({
    required File audio,
    ConfirmedSpeechLocale? locale,
    DateTime? createdAt,
    Future<String?> Function(String path)? readCreationDate,
    Future<String?> Function(File audio, ConfirmedSpeechLocale locale)?
    transcribe,
  }) {
    return SharedAudioBacklogImport.importFile(
      audio: audio,
      locale: locale,
      createdAt: createdAt,
      readCreationDate: readCreationDate,
      transcribe: transcribe,
    );
  }
}

/// Receives shared audio the iOS handler stored until Dart can save it.
abstract final class VoiceMemoImportInbox {
  VoiceMemoImportInbox._();

  /// Transcribes a pending memo and leaves saving to the receipt.
  static Future<JournalEntry?> transcribePending({
    Map<Object?, Object?>? pending,
    required Future<ConfirmedSpeechLocale?> Function() readLocale,
    Future<String?> Function(String path)? readCreationDate,
    Future<String?> Function(File audio, ConfirmedSpeechLocale locale)?
    transcribe,
  }) async {
    final intake = await SharedMediaReceiver.takePending(
      pending: pending,
      readCreationDate: readCreationDate,
    );
    if (intake == null) return null;
    final entry = await VoiceMemoImporter.importFile(
      audio: File(intake.path),
      locale: await readLocale(),
      createdAt: intake.recordedAt,
      transcribe: transcribe,
    );
    if (entry == null) return null;
    return entry;
  }

  static Future<JournalEntry?> consume({
    Map<Object?, Object?>? pending,
    required Future<ConfirmedSpeechLocale?> Function() readLocale,
    required Future<void> Function(JournalEntry entry) save,
    Future<String?> Function(File audio, ConfirmedSpeechLocale locale)?
    transcribe,
  }) async {
    final entry = await transcribePending(
      pending: pending,
      readLocale: readLocale,
      transcribe: transcribe,
    );
    if (entry == null) return null;
    await save(entry);
    return entry;
  }
}
