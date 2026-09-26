import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/features/export/services/universal_export_service.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one zip holds the journal, notes, recordings, photos, and a readme', () async {
    final root = await Directory.systemTemp.createTemp('universal_export');
    addTearDown(() => root.delete(recursive: true));
    final audio = File('${root.path}/note.m4a');
    final photo = File('${root.path}/shot.jpg');
    final thumb = File('${root.path}/shot_thumb.jpg');
    await audio.writeAsBytes([1, 2, 3]);
    await photo.writeAsBytes([4, 5, 6]);
    await thumb.writeAsBytes([7]);

    final bytes = await UniversalExportService.buildZip(
      entries: [
        JournalEntry(
          id: 'e1',
          createdAt: DateTime.utc(2026, 3, 8),
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
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        ),
      ],
      insights: const [],
      exportedAt: DateTime.utc(2026, 3, 9),
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((file) => file.name).toList();
    expect(names, contains('journal.json'));
    expect(names, contains('README.md'));
    expect(names, contains('audio/note.m4a'));
    expect(names, contains('photos/shot.jpg'));
    expect(names.any((name) => name.startsWith('markdown/') && name.endsWith('.md')), isTrue);
    expect(names.any((name) => name.contains('thumb')), isFalse);

    String text(String name) {
      final file = archive.findFile(name)!;
      return utf8.decode(file.content as List<int>);
    }

    final journal = text('journal.json');
    expect(journal, contains('"audio_file": "audio/note.m4a"'));
    expect(journal, contains('photos/shot.jpg'));
    expect(journal, contains('by the river'));
    expect(journal.contains(root.path), isFalse);
    expect(journal.contains('localAudioPath'), isFalse);

    final note = text(names.singleWhere((name) => name.startsWith('markdown/')));
    expect(note, contains('![Audio](audio/note.m4a)'));
    expect(note, contains('![[photos/shot.jpg]]'));
    expect(note, contains('- walk'));

    final readme = text('README.md');
    expect(readme, contains('journal.json'));
    expect(readme, contains('markdown/'));
    expect(readme, contains('audio/'));
    expect(readme, contains('photos/'));
    expect(readme, contains('archiveme_journal_export_v1'));
    expect(readme, contains('audio_file'));
  });
}
