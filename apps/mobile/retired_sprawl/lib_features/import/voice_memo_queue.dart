import 'dart:io';

import 'package:archiveme_mobile/features/import/services/shared_media_receiver.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:crypto/crypto.dart';

class VoiceMemoImportProgress {
  const VoiceMemoImportProgress({
    required this.done,
    required this.total,
    required this.skippedDuplicates,
  });

  final int done;
  final int total;
  final int skippedDuplicates;

  String get label => 'Importing $done of $total';
}

/// Imports shared audio in order, skipping a file whose bytes were saved before.
abstract final class VoiceMemoImportQueue {
  VoiceMemoImportQueue._();

  static String hashBytes(List<int> bytes) => sha256.convert(bytes).toString();

  static Future<List<JournalEntry>> run({
    required List<SharedAudioIntake> items,
    required Set<String> seenHashes,
    required Future<JournalEntry?> Function(SharedAudioIntake item) importOne,
    void Function(VoiceMemoImportProgress progress)? onProgress,
    Future<List<int>> Function(String path)? readBytes,
  }) async {
    final imported = <JournalEntry>[];
    var skipped = 0;
    var done = 0;
    for (final item in items) {
      final bytes = await (readBytes ?? (path) => File(path).readAsBytes())(
        item.path,
      );
      final hash = hashBytes(bytes);
      if (!seenHashes.add(hash)) {
        skipped += 1;
      } else {
        final entry = await importOne(item);
        if (entry != null) imported.add(entry);
      }
      done += 1;
      onProgress?.call(
        VoiceMemoImportProgress(
          done: done,
          total: items.length,
          skippedDuplicates: skipped,
        ),
      );
    }
    return imported;
  }
}

/// Audio shared into Thoughtprint with ACTION_SEND or ACTION_SEND_MULTIPLE.
abstract final class AndroidAudioShare {
  AndroidAudioShare._();

  static const send = 'android.intent.action.SEND';
  static const sendMultiple = 'android.intent.action.SEND_MULTIPLE';
  static const extensions = ['.m4a', '.mp3', '.wav', '.ogg'];

  static bool acceptsMime(String? mime) {
    if (mime == null || mime.isEmpty) return false;
    return mime == 'audio/*' || mime.startsWith('audio/');
  }

  static bool acceptsPath(String path) {
    final lower = path.toLowerCase();
    return extensions.any(lower.endsWith);
  }

  static List<String> paths({
    required String action,
    String? mime,
    String? stream,
    List<String>? streams,
  }) {
    if (action != send && action != sendMultiple) return const [];
    if (!acceptsMime(mime)) return const [];
    final candidates = action == send
        ? <String>[if (stream != null && stream.isNotEmpty) stream]
        : <String>[...?streams?.where((path) => path.isNotEmpty)];
    return [
      for (final path in candidates)
        if (acceptsPath(path) || acceptsMime(mime)) path,
    ];
  }
}
