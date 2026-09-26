import 'dart:io';

import 'package:archiveme_mobile/core/storage/secure_file_storage.dart';
import 'package:archiveme_mobile/features/export/archive_book_exporter.dart';
import 'package:archiveme_mobile/features/export/obsidian_archive_exporter.dart';
import 'package:archiveme_mobile/features/media/photo_storage.dart';
import 'package:archiveme_mobile/features/media/services/image_processor_service.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _reflection = Reflection(
  mood: '',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a photo is downscaled to 2048 and a 400px thumbnail without GPS', () async {
    final dir = await Directory.systemTemp.createTemp('photo_scale_');
    addTearDown(() => dir.delete(recursive: true));
    final raw = File('${dir.path}/raw.jpg');
    final source = img.Image(width: 4000, height: 2000);
    source.clear(img.ColorRgb8(10, 20, 30));
    source.exif.gpsIfd.setGpsLocation(latitude: 51.5, longitude: -0.12);
    await raw.writeAsBytes(img.encodeJpg(source));
    SecureFileStorage.debugProtect = (_) async {};
    addTearDown(() => SecureFileStorage.debugProtect = null);

    final stored = await ImageProcessorService(
      documentsDirectory: () async => dir,
    ).processAndStoreImage(raw, entryId: 'moment-9', keepGps: false);

    expect(stored.highResPath, contains('/photos/moment-9/'));
    final full = img.decodeJpg(File(stored.highResPath).readAsBytesSync())!;
    expect(full.width, 2048);
    expect(full.height, closeTo(1024, 2));
    expect(full.exif.imageIfd.sub.directories.containsKey('gps'), isFalse);
    final thumb = img.decodeJpg(File(stored.thumbnailPath).readAsBytesSync())!;
    expect(mathMax(thumb.width, thumb.height), 400);

    final kept = await ImageProcessorService(
      documentsDirectory: () async => dir,
    ).processAndStoreImage(raw, entryId: 'moment-9', keepGps: true);
    final withGps = img.decodeJpg(File(kept.highResPath).readAsBytesSync())!;
    expect(withGps.exif.gpsIfd.gpsLatitude, isNotNull);
  });

  test('iOS file protection is set through the platform channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SecureFileStorage.channel, (call) async {
          calls.add(call);
          return null;
        });
    SecureFileStorage.debugForceChannel = true;
    addTearDown(() {
      SecureFileStorage.debugForceChannel = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SecureFileStorage.channel, null);
    });
    final dir = await Directory.systemTemp.createTemp('photo_protect_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/shot.jpg';
    await SecureFileStorage.writeImage(path: path, bytes: const [1, 2, 3]);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'setFileProtectionComplete');
    expect(calls.single.arguments, path);
  });

  test('deleting an entry removes its photo folder', () async {
    final dir = await Directory.systemTemp.createTemp('photo_delete_');
    addTearDown(() => dir.delete(recursive: true));
    final folder = Directory('${dir.path}/photos/e1');
    await folder.create(recursive: true);
    final photo = File('${folder.path}/shot.jpg')..writeAsBytesSync([1, 2, 3]);
    final thumb = File('${folder.path}/shot_thumb.jpg')
      ..writeAsBytesSync([4]);
    final journal = await JournalStore.open('${dir.path}/entries.json');
    await journal.save(
      JournalEntry(
        id: 'e1',
        createdAt: DateTime.utc(2026, 9, 1),
        transcript: 'The river',
        durationSeconds: 1,
        reflection: _reflection,
        imageEvidence: ImageEvidence(
          evidenceId: 'e1',
          caption: '',
          mimeType: 'image/jpeg',
          attachedAt: DateTime.utc(2026, 9, 1),
          images: [photo.path],
        ),
      ),
    );
    final service = PrivateDataService(
      journalStore: journal,
      tempDirProvider: () async => dir,
    );

    final result = await service.deleteEntrySecurely('e1');

    expect(result.deleted, isTrue);
    expect(photo.existsSync(), isFalse);
    expect(thumb.existsSync(), isFalse);
    expect(folder.existsSync(), isFalse);
  });

  test('wiping the archive removes every photo', () async {
    final dir = await Directory.systemTemp.createTemp('photo_wipe_');
    addTearDown(() => dir.delete(recursive: true));
    final photos = Directory('${dir.path}/photos/e2');
    await photos.create(recursive: true);
    final photo = File('${photos.path}/shot.jpg')..writeAsBytesSync([9]);
    final journal = await JournalStore.open('${dir.path}/entries.json');
    await journal.save(
      JournalEntry(
        id: 'e2',
        createdAt: DateTime.utc(2026, 9, 2),
        transcript: 'The bridge',
        durationSeconds: 1,
        reflection: _reflection,
        imageEvidence: ImageEvidence(
          evidenceId: 'e2',
          caption: '',
          mimeType: 'image/jpeg',
          attachedAt: DateTime.utc(2026, 9, 2),
          images: [photo.path],
        ),
      ),
    );
    final service = PrivateDataService(
      journalStore: journal,
      tempDirProvider: () async => dir,
    );

    await service.wipeAllLocalArchive(
      confirmationPhrase: PrivateDataService.wipeConfirmationPhrase,
    );

    expect(Directory('${dir.path}/photos').existsSync(), isFalse);
  });

  test('original-quality copies can be removed without the stored photo', () {
    final dir = Directory.systemTemp.createTempSync('photo_originals_');
    addTearDown(() => dir.delete(recursive: true));
    final folder = Directory('${dir.path}/photos/e3')..createSync(recursive: true);
    File('${folder.path}/kept.jpg').writeAsBytesSync(List<int>.filled(100, 1));
    File(
      '${folder.path}/kept_original.jpg',
    ).writeAsBytesSync(List<int>.filled(500, 2));

    expect(PhotoStorage.hasOriginals(Directory('${dir.path}/photos')), isTrue);
    final freed = PhotoStorage.removeOriginalQualityCopies(
      Directory('${dir.path}/photos'),
    );
    expect(freed, 500);
    expect(File('${folder.path}/kept.jpg').existsSync(), isTrue);
    expect(File('${folder.path}/kept_original.jpg').existsSync(), isFalse);
  });

  test('an Obsidian note embeds the photo inside the archive', () {
    final notes = ObsidianArchiveExporter.markdownDocuments(
      entries: [
        ArchiveBookEntry(
          id: 'moment',
          recordedAt: DateTime.utc(2026, 8, 3),
          transcript: 'The river was high.',
          photoFileNames: const ['photos/moment.jpg'],
        ),
      ],
    );
    final markdown = String.fromCharCodes(notes.values.single);
    expect(markdown, contains('![[photos/moment.jpg]]'));
  });
}

int mathMax(int a, int b) => a > b ? a : b;
