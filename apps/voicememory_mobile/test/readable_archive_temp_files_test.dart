import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_export/complete_archive_export.dart';
import 'package:voicememory_mobile/features/archive_export/readable_archive_temp_files.dart';

void main() {
  test(
    'fixed-name and stale-directory symlinks cannot redirect readable files',
    () async {
      if (Platform.isWindows) return;
      final root = await Directory.systemTemp.createTemp(
        'readable_export_test_',
      );
      final outside = await Directory.systemTemp.createTemp(
        'readable_export_outside_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      const secretValue = 'DO_NOT_OVERWRITE_OR_EXPORT_THIS_SECRET';
      final secret = File('${outside.path}/secret.txt');
      await secret.writeAsString(secretValue);
      await Link(
        '${root.path}/${ArchiveExportBundle.readableFileName}',
      ).create(secret.path);
      final outsideDirectory = Directory('${outside.path}/escaped');
      await outsideDirectory.create();
      final staleLink = Link(
        '${root.path}/${ReadableArchiveTempFiles.directoryPrefix}attacker',
      );
      await staleLink.create(outsideDirectory.path);
      final bundle = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: const [],
      );

      final files = await ReadableArchiveTempFiles.create(root);
      addTearDown(files.cleanup);
      await files.write(bundle);

      expect(files.directory.parent.path, root.path);
      expect(
        await FileSystemEntity.type(files.readable.path, followLinks: false),
        FileSystemEntityType.file,
      );
      expect(await secret.readAsString(), secretValue);
      expect(await staleLink.exists(), isTrue);
      expect(await outsideDirectory.list().isEmpty, isTrue);
      expect(await files.readable.readAsString(), isNot(contains(secretValue)));
      expect(
        await files.machineReadable.readAsString(),
        isNot(contains(outside.path)),
      );
    },
  );
}
