import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/features/export/services/zip_archiver_service.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zip copies recordings and full-size photos under relative names', () async {
    final root = await Directory.systemTemp.createTemp('zip_archiver_test');
    addTearDown(() => root.delete(recursive: true));
    final audio = File('${root.path}/note.m4a');
    final photo = File('${root.path}/shot.jpg');
    final thumb = File('${root.path}/shot_thumb.jpg');
    await audio.writeAsBytes([1, 2, 3]);
    await photo.writeAsBytes([4, 5, 6]);
    await thumb.writeAsBytes([7]);

    final entry = JournalEntry(
      id: 'e1',
      createdAt: DateTime.utc(2026, 3, 8),
      transcript: 'by the river',
      durationSeconds: 4,
      localAudioPath: audio.path,
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
    );
    final packed = await ZipArchiverService.packEntries([entry]);
    final journal = jsonEncode(
      ZipArchiverService.portableMediaFields(
        audioPath: entry.audioUrl,
        images: entry.images,
      ),
    );
    final bytes = ZipArchiverService.encode(
      documents: {'journal.json': utf8.encode(journal)},
      audio: packed.audioByName,
      photos: packed.photosByName,
    );
    final names = ZipDecoder().decodeBytes(bytes).files.map((file) => file.name);
    expect(names, containsAll(['journal.json', 'audio/note.m4a', 'photos/shot.jpg']));
    expect(names.any((name) => name.contains('thumb')), isFalse);
    final stored = utf8.decode(
      ZipDecoder()
          .decodeBytes(bytes)
          .findFile('journal.json')!
          .content as List<int>,
    );
    expect(stored, contains('audio/note.m4a'));
    expect(stored, contains('photos/shot.jpg'));
    expect(stored.contains(root.path), isFalse);
  });
}