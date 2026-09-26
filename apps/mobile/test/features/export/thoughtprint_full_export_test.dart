import 'dart:io';

import 'package:archiveme_mobile/features/export/services/thoughtprint_full_export.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/backlog_import_service.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:archiveme_mobile/core/network/http_transport.dart';

void main() {
  test('export and import keep entries, audio, and photos by hash', () async {
    final root = await Directory.systemTemp.createTemp('thoughtprint_export');
    addTearDown(() => root.delete(recursive: true));
    final audioBytes = [1, 2, 3, 9, 8];
    final photoBytes = [4, 5, 6, 7, 1];
    final audio = File('${root.path}/note.m4a');
    final photo = File('${root.path}/shot.jpg');
    final thumb = File('${root.path}/shot_thumb.jpg');
    await audio.writeAsBytes(audioBytes);
    await photo.writeAsBytes(photoBytes);
    await thumb.writeAsBytes([8]);
    final progress = <double>[];

    final zip = await ThoughtprintFullExport.write(
      entries: [
        JournalEntry(
          id: 'river',
          createdAt: DateTime.utc(2026, 3, 8, 15),
          transcript: 'by the river',
          durationSeconds: 4,
          localAudioPath: audio.path,
          captureContextTag: 'walk',
          imageEvidence: ImageEvidence(
            evidenceId: 'img',
            caption: '',
            mimeType: 'image/jpeg',
            attachedAt: DateTime.utc(2026, 3, 8),
            images: [photo.path, thumb.path],
          ),
          reflection: const Reflection(
            mood: 'calm',
            emotionalIntensity: 1,
            recurringThemes: ['water'],
            exactLanguagePattern: 'by the river',
            concreteObservation: 'the bank',
            repeatedSignal: 'water',
          ),
        ),
      ],
      outputDirectory: root,
      exportedAt: DateTime.utc(2026, 9, 26),
      includeBook: true,
      bookPdf: const [37, 80, 68, 70],
      onProgress: progress.add,
    );

    expect(zip.uri.pathSegments.last, 'thoughtprint-export-2026-09-26.zip');
    expect(progress, isNotEmpty);
    expect(progress.last, 1);

    final restoredDir = Directory('${root.path}/restored');
    final restored = await ThoughtprintFullExport.read(zip, restoredDir);
    final entry = restored.single;
    expect(entry.transcript, 'by the river');
    expect(entry.id, 'river');
    expect(
      entry.audioHash,
      sha256.convert(audioBytes).toString(),
    );
    expect(entry.photoHashes, [sha256.convert(photoBytes).toString()]);
    expect(entry.photoPaths.single, contains('photos/river/1.jpg'));
    expect(entry.audioPath, contains('audio/river.m4a'));

    final archiveBytes = await zip.readAsBytes();
    final journal = String.fromCharCodes(archiveBytes);
    expect(journal.contains(root.path), isFalse);
    expect(journal.contains('localAudioPath'), isFalse);

    final chunks = BacklogImportService(
      HttpTransport(client: http.Client()),
    ).parseSelectedFiles([
      PlatformFile(
        name: 'thoughtprint-export-2026-09-26.zip',
        size: archiveBytes.length,
        bytes: archiveBytes,
      ),
    ]);
    expect(chunks.single.rawText, 'by the river');
    expect(chunks.single.audioPath, contains('audio/river.m4a'));
  });
}
