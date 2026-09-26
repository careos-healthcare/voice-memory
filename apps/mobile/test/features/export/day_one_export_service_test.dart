import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/features/export/services/day_one_export_service.dart';
import 'package:archiveme_mobile/features/moment_quality/post_save_moment_detail_model.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/journal_proof_data.dart';
import 'package:archiveme_mobile/models/journal_sync_metadata.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('day one zip names photos and audio by their md5', () async {
    final root = await Directory.systemTemp.createTemp('day_one_export');
    addTearDown(() => root.delete(recursive: true));
    final audioBytes = [1, 2, 3, 9];
    final photoBytes = [4, 5, 6, 7];
    final audio = File('${root.path}/note.m4a');
    final photo = File('${root.path}/shot.jpg');
    final thumb = File('${root.path}/shot_thumb.jpg');
    await audio.writeAsBytes(audioBytes);
    await photo.writeAsBytes(photoBytes);
    await thumb.writeAsBytes([8]);
    final audioHash = md5.convert(audioBytes).toString();
    final photoHash = md5.convert(photoBytes).toString();

    final created = DateTime.utc(2026, 3, 8, 15);
    final bytes = await DayOneExportService.buildZip(
      entries: [
        _entry(
          id: 'moment-1',
          transcript: 'by the river',
          createdAt: created,
          audioPath: audio.path,
          images: [photo.path, thumb.path],
          latitude: 51.5,
          longitude: -0.12,
          place: 'bridge',
        ),
        _entry(
          id: 'follow-1',
          transcript: 'the water was high',
          createdAt: created.add(const Duration(minutes: 2)),
          tag: PostSaveMomentDetailType.linkedCaptureContextTag(
            type: PostSaveMomentDetailType.stoodOut,
            parentEntryId: 'moment-1',
          ),
        ),
      ],
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((file) => file.name).toList();
    expect(names, contains('Journal.json'));
    expect(names, contains('photos/$photoHash.jpeg'));
    expect(names, contains('audio/$audioHash.m4a'));
    expect(names.any((name) => name.contains('thumb')), isFalse);
    expect(names.any((name) => name.contains(root.path)), isFalse);

    final journal = jsonDecode(
      utf8.decode(archive.findFile('Journal.json')!.content as List<int>),
    ) as Map<String, dynamic>;
    final row = (journal['entries'] as List).single as Map<String, dynamic>;
    expect(row['text'], 'by the river\n\nthe water was high');
    expect(row['creationDate'], created.toIso8601String());
    expect(row['timeZone'], 'UTC');
    expect(row['location'], {
      'latitude': 51.5,
      'longitude': -0.12,
      'placeName': 'bridge',
    });
    final photos = row['photos'] as List;
    final audioObjects = row['audio'] as List;
    expect(photos.single['md5'], photoHash);
    expect(audioObjects.single['md5'], audioHash);
    expect(row['audios'], audioObjects);
    expect(row['uuid'], 'moment-1');
    expect(DayOneExportService.matchesDocumentedFields(journal), isTrue);
    expect(journal.toString().contains(root.path), isFalse);
  });
}

JournalEntry _entry({
  required String id,
  required String transcript,
  required DateTime createdAt,
  String? audioPath,
  List<String> images = const [],
  String? tag,
  double? latitude,
  double? longitude,
  String? place,
}) {
  return JournalEntry.stored(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 4,
    localAudioPath: audioPath,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    sync: JournalSyncMetadata(createdAt: createdAt, entryId: id),
    display: JournalDisplayMetadata(
      captureContextTag: tag,
      latitude: latitude,
      longitude: longitude,
      locationLabel: place,
    ),
    proof: JournalProofData(
      imageEvidence: images.isEmpty
          ? null
          : ImageEvidence(
              evidenceId: 'img-$id',
              caption: '',
              mimeType: 'image/jpeg',
              attachedAt: createdAt,
              images: images,
            ),
    ),
  );
}
