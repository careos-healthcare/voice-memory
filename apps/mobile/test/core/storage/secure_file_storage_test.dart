import 'dart:io';

import 'package:archiveme_mobile/core/storage/secure_file_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a saved image is written and then marked complete protection',
    () async {
      final dir = await Directory.systemTemp.createTemp('secure_image_');
      final path = '${dir.path}/journal.jpg';
      final seen = <String>[];
      SecureFileStorage.debugProtect = (filePath) async {
        seen.add(filePath);
      };
      addTearDown(() => SecureFileStorage.debugProtect = null);

      final file = await SecureFileStorage.writeImage(
        path: path,
        bytes: [1, 2, 3, 4],
      );

      expect(file.readAsBytesSync(), [1, 2, 3, 4]);
      expect(seen, [path]);
      await dir.delete(recursive: true);
    },
  );
}
