import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_export/complete_archive_export.dart';
import 'package:voicememory_mobile/features/archive_export/full_archive_export.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';

const _reflection = Reflection(
  mood: 'calm',
  emotionalIntensity: 2,
  recurringThemes: ['work'],
  exactLanguagePattern: 'exact words',
  concreteObservation: 'validated observation',
  repeatedSignal: 'uncertain signal',
);

JournalEntry _entry(String id, {String? vaultRef, String? legacyPath}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 8, 1, 12),
      transcript: 'Original text with a correction.',
      durationSeconds: 4,
      reflection: _reflection,
      localAudioVaultRef: vaultRef,
      localAudioPath: legacyPath,
    );

Map<String, Object?> _manifestFrom(Archive archive) {
  final file = archive.files.singleWhere(
    (file) => file.name == 'manifest.json',
  );
  return jsonDecode(utf8.decode(file.content)) as Map<String, Object?>;
}

bool _containsSequence(List<int> bytes, List<int> sequence) {
  if (sequence.isEmpty) return true;
  for (var start = 0; start <= bytes.length - sequence.length; start++) {
    var matches = true;
    for (var offset = 0; offset < sequence.length; offset++) {
      if (bytes[start + offset] != sequence[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

void main() {
  late Directory root;
  late Directory vaultDirectory;
  late Directory vaultTemp;
  late Directory exportTemp;
  late AudioVaultService vault;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('full_export_test_');
    vaultDirectory = Directory('${root.path}/vault');
    vaultTemp = Directory('${root.path}/vault_temp');
    exportTemp = Directory('${root.path}/exports');
    vault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async => vaultDirectory,
      temporaryDirectory: () async => vaultTemp,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> seal(String id, List<int> bytes) async {
    final source = File('${root.path}/$id.m4a');
    await source.writeAsBytes(bytes);
    return (await vault.sealCapture(id, source)).reference;
  }

  FullArchiveExportBuilder builder({
    String exportId = 'opaque-export-id',
    void Function(String path)? onItemAdded,
  }) => FullArchiveExportBuilder(
    audioVault: vault,
    temporaryRoot: exportTemp,
    appVersion: '0.2.0+49',
    clock: () => DateTime.utc(2026, 8, 4, 3, 30),
    exportIdFactory: () => exportId,
    onItemAdded: onItemAdded,
  );

  test(
    'full ZIP contains readable, JSON, audio, and checksummed manifest',
    () async {
      final audio = List<int>.generate(4096, (index) => index % 251);
      final reference = await seal('moment-one', audio);
      final entry = _entry('moment/../one', vaultRef: reference);
      final readable = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [entry],
      );

      final result = await builder().build(
        readable: readable,
        entries: [entry],
        audioExportConfirmed: true,
      );
      addTearDown(result.cleanup);
      final archive = ZipDecoder().decodeBytes(
        await result.archive.readAsBytes(),
      );
      final names = archive.files.map((file) => file.name).toList();

      expect(names, containsAll(['readable/archive.md', 'data/archive.json']));
      expect(names, contains('manifest.json'));
      final audioFile = archive.files.singleWhere(
        (file) => file.name.startsWith('audio/'),
      );
      expect(audioFile.name, isNot(contains('..')));
      expect(audioFile.content, audio);

      final manifest = _manifestFrom(archive);
      expect(manifest['formatVersion'], FullArchiveExportBuilder.formatVersion);
      expect(manifest['exportId'], 'opaque-export-id');
      expect(manifest['exportedAt'], '2026-08-04T03:30:00.000Z');
      expect(manifest['appVersion'], '0.2.0+49');
      final items = (manifest['items'] as List).cast<Map<String, Object?>>();
      final audioItem = items.singleWhere(
        (item) => item['path'] == audioFile.name,
      );
      expect(audioItem['result'], 'included');
      expect(audioItem['size'], audio.length);
      expect(audioItem['sha256'], sha256.convert(audio).toString());
      expect(audioItem['sourceRef'], reference);
      expect(audioItem['sourceDate'], '2026-08-01T12:00:00.000Z');
      expect(vaultTemp.listSync(), isEmpty);
      expect(
        exportTemp.listSync().whereType<Directory>(),
        isEmpty,
        reason: 'opaque working directory is removed after success',
      );
    },
  );

  test(
    'reports missing, corrupt, unsupported, and traversal references',
    () async {
      final corruptRef = await seal('corrupt', List<int>.filled(200, 7));
      final corruptFile = await vault.resolveReference(corruptRef);
      final bytes = await corruptFile.readAsBytes();
      bytes[bytes.length - 1] ^= 0xff;
      await corruptFile.writeAsBytes(bytes);
      final legacy = File('${root.path}/legacy.wav');
      await legacy.writeAsBytes([82, 73, 70, 70, 1, 2, 3]);
      final unsupported = File('${root.path}/unsupported.txt');
      await unsupported.writeAsString('not audio');
      final entries = [
        _entry('missing', vaultRef: 'av1:not-there.m4a.enc'),
        _entry('corrupt', vaultRef: corruptRef),
        _entry('legacy', legacyPath: legacy.path),
        _entry('unsupported', legacyPath: unsupported.path),
        _entry('traversal', vaultRef: 'av1:../outside.enc'),
      ];
      final readable = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: entries,
      );

      final result = await builder().build(
        readable: readable,
        entries: entries,
        audioExportConfirmed: true,
      );
      addTearDown(result.cleanup);
      final reports = result.manifest['reports'] as Map<String, Object?>;

      expect(reports['missing'], hasLength(1));
      expect(reports['corrupt'], hasLength(1));
      expect(reports['unsupported'], isEmpty);
      expect(reports['inaccessible'], hasLength(3));
      expect(jsonEncode(result.manifest), isNot(contains(root.path)));
      expect(jsonEncode(result.manifest), isNot(contains('../')));
      expect(vaultTemp.listSync(), isEmpty);
      final archive = ZipDecoder().decodeBytes(
        await result.archive.readAsBytes(),
      );
      expect(
        archive.files.where((file) => file.name.startsWith('audio/')),
        isEmpty,
      );
    },
  );

  test(
    'never reads a regular secret file referenced by a legacy host path',
    () async {
      final outsideRoot = await Directory.systemTemp.createTemp(
        'full_export_outside_',
      );
      addTearDown(() async {
        if (await outsideRoot.exists()) {
          await outsideRoot.delete(recursive: true);
        }
      });
      final secretBytes = utf8.encode('HOST_SECRET_MUST_NOT_BE_EXPORTED_9471');
      final secret = File('${outsideRoot.path}/innocent-looking.m4a');
      await secret.writeAsBytes(secretBytes);
      expect(
        await FileSystemEntity.type(secret.path, followLinks: false),
        FileSystemEntityType.file,
      );
      final entry = _entry('crafted-legacy', legacyPath: secret.path);
      final readable = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [entry],
      );

      final result = await builder().build(
        readable: readable,
        entries: [entry],
        audioExportConfirmed: true,
      );
      addTearDown(result.cleanup);
      final archiveBytes = await result.archive.readAsBytes();
      final archive = ZipDecoder().decodeBytes(archiveBytes);
      final manifest = _manifestFrom(archive);
      final reports = manifest['reports'] as Map<String, Object?>;

      expect(reports['inaccessible'], hasLength(1));
      expect(
        archive.files.where((file) => file.name.startsWith('audio/')),
        isEmpty,
      );
      expect(jsonEncode(manifest), isNot(contains(secret.path)));
      expect(jsonEncode(manifest), isNot(contains(outsideRoot.path)));
      expect(
        archive.files.any(
          (file) => _containsSequence(file.content, secretBytes),
        ),
        isFalse,
      );
    },
  );

  test('rejects symlinked vault objects without following them', () async {
    if (Platform.isWindows) return;
    await vaultDirectory.create(recursive: true);
    final outside = File('${root.path}/outside.m4a.enc');
    await outside.writeAsBytes([1, 2, 3]);
    await Link('${vaultDirectory.path}/linked.m4a.enc').create(outside.path);
    final entry = _entry('linked', vaultRef: 'av1:linked.m4a.enc');
    final readable = CompleteArchiveExportBuilder.build(
      archiveId: 'local',
      entries: [entry],
    );

    final result = await builder().build(
      readable: readable,
      entries: [entry],
      audioExportConfirmed: true,
    );
    addTearDown(result.cleanup);

    final reports = result.manifest['reports'] as Map<String, Object?>;
    expect(reports['inaccessible'], hasLength(1));
    final archive = ZipDecoder().decodeBytes(
      await result.archive.readAsBytes(),
    );
    expect(
      archive.files.where((file) => file.name.startsWith('audio/')),
      isEmpty,
    );
  });

  test(
    'cancellation and failure remove output and stale private work',
    () async {
      await exportTemp.create(recursive: true);
      final stale = Directory(
        '${exportTemp.path}/.archiveme_export_work_stale',
      );
      await stale.create();
      await File('${stale.path}/plaintext.tmp').writeAsString('private');
      final cancellation = ArchiveExportCancellation();
      final readable = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: const [],
      );

      await expectLater(
        builder(
          exportId: 'cancelled',
          onItemAdded: (_) => cancellation.cancel(),
        ).build(
          readable: readable,
          entries: const [],
          audioExportConfirmed: true,
          cancellation: cancellation,
        ),
        throwsA(isA<ArchiveExportCancelled>()),
      );

      expect(await stale.exists(), isFalse);
      expect(
        exportTemp.listSync().where((entity) => entity.path.endsWith('.zip')),
        isEmpty,
      );
    },
  );

  test(
    'confirmation is mandatory and archive contains no key material',
    () async {
      final reference = await seal('secret-check', List<int>.filled(256, 19));
      final entry = _entry('secret-check', vaultRef: reference);
      final readable = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [entry],
      );

      await expectLater(
        builder().build(
          readable: readable,
          entries: [entry],
          audioExportConfirmed: false,
        ),
        throwsStateError,
      );

      final result = await builder().build(
        readable: readable,
        entries: [entry],
        audioExportConfirmed: true,
      );
      addTearDown(result.cleanup);
      final zipText = latin1.decode(
        await result.archive.readAsBytes(),
        allowInvalid: true,
      );
      expect(zipText, isNot(contains('recoveryCode')));
      expect(zipText, isNot(contains('syncKey')));
      expect(zipText, isNot(contains('accessToken')));
      expect(zipText, isNot(contains(root.path)));
    },
  );
}
