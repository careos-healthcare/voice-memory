import 'dart:io';

import 'package:archiveme_mobile/features/import/services/backlog_import_service.dart';

export 'package:archiveme_mobile/features/import/services/backlog_import_service.dart'
    show VoiceMemoTitles;
import 'package:archiveme_mobile/features/import/services/shared_media_receiver.dart';
import 'package:archiveme_mobile/features/import/views/voice_memo_import_progress.dart';
import 'package:archiveme_mobile/features/import/voice_memo_queue.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Turns shared Voice Memos audio into a backdated journal entry.
abstract final class VoiceMemoImporter {
  VoiceMemoImporter._();

  static const captureSource = SharedAudioBacklogImport.captureSource;

  static bool accepts(String path) => SharedMediaReceiver.accepts(path);

  static Future<JournalEntry?> importFile({
    required File audio,
    ConfirmedSpeechLocale? locale,
    DateTime? createdAt,
    String? name,
    Future<String?> Function(String path)? readCreationDate,
    Future<String?> Function(File audio, ConfirmedSpeechLocale locale)?
    transcribe,
  }) {
    return SharedAudioBacklogImport.importFile(
      audio: audio,
      locale: locale,
      createdAt: createdAt,
      name: name,
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
      name: intake.name,
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

  /// Transcribes every shared file, skips hashes already imported, and
  /// opens a receipt for each new memo.
  static Future<List<JournalEntry>> importQueue({
    List<SharedAudioIntake>? items,
    required Future<ConfirmedSpeechLocale?> Function() readLocale,
    required Future<void> Function(JournalEntry entry) save,
    Set<String>? seenHashes,
    void Function(VoiceMemoImportProgress progress)? onProgress,
    Future<String?> Function(File audio, ConfirmedSpeechLocale locale)?
    transcribe,
    bool presentReceipts = true,
  }) async {
    final batch = items ?? await SharedMediaReceiver.takeAll();
    if (batch.isEmpty) return const [];
    final seen = seenHashes ?? await VoiceMemoHashLog.load();
    final locale = await readLocale();
    final imported = await VoiceMemoImportQueue.run(
      items: batch,
      seenHashes: seen,
      onProgress: onProgress ?? VoiceMemoImportProgressHub.report,
      importOne: (item) => VoiceMemoImporter.importFile(
        audio: File(item.path),
        locale: locale,
        createdAt: item.recordedAt,
        name: item.name,
        transcribe: transcribe,
      ),
    );
    if (seenHashes == null) await VoiceMemoHashLog.save(seen);
    if (!presentReceipts) return imported;
    for (final entry in imported) {
      await openImportReceipt(entry: entry, save: save);
    }
    return imported;
  }
}

abstract final class VoiceMemoHashLog {
  VoiceMemoHashLog._();

  static const preferenceKey = 'voice_memo_import_hashes';

  static Future<Set<String>> load() async {
    if (!AppServices.isInitialized) return {};
    final raw = await AppServices.instance.prefs.readString(preferenceKey);
    if (raw == null || raw.isEmpty) return {};
    return raw.split('\n').where((line) => line.isNotEmpty).toSet();
  }

  static Future<void> save(Set<String> hashes) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(
      preferenceKey,
      hashes.join('\n'),
    );
  }
}
