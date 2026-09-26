import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/backup/encrypted_archive_backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('archive_backup_test');
  });

  tearDown(() async {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  test('encrypted backup stays off', () {
    expect(V1CapabilityRegistry.encryptedBackup, isFalse);
  });

  test('round-trip restores the database and audio', () async {
    final sourceDb = File('${root.path}/source.db');
    final sourceAudio = Directory('${root.path}/audio');
    await sourceAudio.create();
    await sourceDb.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));
    await File('${sourceAudio.path}/clip.m4a').writeAsBytes([9, 8, 7]);

    final sealed = await EncryptedArchiveBackupCodec.seal(
      databaseFile: sourceDb,
      audioDirectory: sourceAudio,
      passphrase: 'correct horse',
      profile: ArchiveBackupKdfProfile.test,
    );

    final restoredDb = File('${root.path}/restored.db');
    final restoredAudio = Directory('${root.path}/restored-audio');
    await EncryptedArchiveBackupCodec.restore(
      sealed: sealed,
      passphrase: 'correct horse',
      databaseFile: restoredDb,
      audioDirectory: restoredAudio,
    );

    expect(await restoredDb.readAsBytes(), [1, 2, 3, 4, 5]);
    expect(await File('${restoredAudio.path}/clip.m4a').readAsBytes(), [
      9,
      8,
      7,
    ]);
  });

  test('encrypted backup keeps full-size photos beside the audio', () async {
    final sourceDb = File('${root.path}/source.db');
    final sourceAudio = Directory('${root.path}/audio');
    final sourcePhotos = Directory('${root.path}/photos');
    await sourceAudio.create();
    await sourcePhotos.create();
    await sourceDb.writeAsBytes([1, 2, 3]);
    await File('${sourceAudio.path}/clip.m4a').writeAsBytes([9]);
    await File('${sourcePhotos.path}/shot.jpg').writeAsBytes([4, 5]);
    await File('${sourcePhotos.path}/shot_thumb.jpg').writeAsBytes([1]);

    final sealed = await EncryptedArchiveBackupCodec.seal(
      databaseFile: sourceDb,
      audioDirectory: sourceAudio,
      photosDirectory: sourcePhotos,
      passphrase: 'correct horse',
      profile: ArchiveBackupKdfProfile.test,
    );

    final restoredPhotos = Directory('${root.path}/restored-photos');
    await EncryptedArchiveBackupCodec.restore(
      sealed: sealed,
      passphrase: 'correct horse',
      databaseFile: File('${root.path}/restored.db'),
      audioDirectory: Directory('${root.path}/restored-audio'),
      photosDirectory: restoredPhotos,
    );

    expect(await File('${restoredPhotos.path}/shot.jpg').readAsBytes(), [
      4,
      5,
    ]);
    expect(File('${restoredPhotos.path}/shot_thumb.jpg').existsSync(), isFalse);
  });

  test('wrong passphrase fails cleanly', () async {
    final sourceDb = File('${root.path}/source.db');
    await sourceDb.writeAsBytes([1, 2, 3, 4]);
    final sealed = await EncryptedArchiveBackupCodec.seal(
      databaseFile: sourceDb,
      audioDirectory: Directory('${root.path}/missing-audio'),
      passphrase: 'correct horse',
      profile: ArchiveBackupKdfProfile.test,
    );

    expect(
      () => EncryptedArchiveBackupCodec.open(
        sealed: sealed,
        passphrase: 'wrong phrase',
      ),
      throwsA(
        isA<EncryptedArchiveBackupException>().having(
          (error) => error.code,
          'code',
          'WRONG_PASSPHRASE',
        ),
      ),
    );
  });

  test('corrupted file fails without touching the existing database', () async {
    final existing = File('${root.path}/existing.db');
    await existing.writeAsBytes([7, 7, 7, 7]);
    final before = await existing.readAsBytes();

    await expectLater(
      EncryptedArchiveBackupCodec.restore(
        sealed: Uint8List.fromList([0, 1, 2, 3, 4, 5]),
        passphrase: 'correct horse',
        databaseFile: existing,
        audioDirectory: Directory('${root.path}/audio-out'),
      ),
      throwsA(
        isA<EncryptedArchiveBackupException>().having(
          (error) => error.code,
          'code',
          'CORRUPT_ARCHIVE',
        ),
      ),
    );

    expect(await existing.readAsBytes(), before);
  });
}
