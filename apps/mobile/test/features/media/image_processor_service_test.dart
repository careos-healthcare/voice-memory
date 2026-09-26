import 'dart:io';
import 'dart:math' as math;

import 'package:archiveme_mobile/core/storage/secure_file_storage.dart';
import 'package:archiveme_mobile/features/media/services/image_processor_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test(
    'a wide photo is stored as a 2048px jpeg and a cropped square preview',
    () async {
      final dir = await Directory.systemTemp.createTemp('image_processor_');
      final raw = File('${dir.path}/raw.png');
      final source = img.Image(width: 3000, height: 1000);
      img.fillRect(
        source,
        x1: 0,
        y1: 0,
        x2: 999,
        y2: 999,
        color: img.ColorRgb8(0, 180, 0),
      );
      img.fillRect(
        source,
        x1: 1000,
        y1: 0,
        x2: 2999,
        y2: 999,
        color: img.ColorRgb8(200, 10, 10),
      );
      await raw.writeAsBytes(img.encodePng(source));

      final protected = <String>[];
      SecureFileStorage.debugProtect = (path) async {
      protected.add(path);
    };
      addTearDown(() => SecureFileStorage.debugProtect = null);

      final stored = await ImageProcessorService(
        documentsDirectory: () async => dir,
      ).processAndStoreImage(raw);

      expect(stored.highResPath, startsWith('${dir.path}/photos/_inbox/'));
      expect(stored.highResPath, endsWith('.jpg'));
      expect(stored.thumbnailPath, endsWith('_thumb.jpg'));
      expect(protected, [stored.highResPath, stored.thumbnailPath]);

      final full = img.decodeImage(File(stored.highResPath).readAsBytesSync())!;
      expect(full.width, ImageProcessorService.maxEdge);
      expect(full.height, lessThanOrEqualTo(ImageProcessorService.maxEdge));
      expect(full.height, closeTo(683, 2));

      final thumb = img.decodeImage(
        File(stored.thumbnailPath).readAsBytesSync(),
      )!;
      expect(math.max(thumb.width, thumb.height), ImageProcessorService.thumbnailSize);
      expect(thumb.width, 400);
      expect(thumb.height, closeTo(133, 2));
      final center = thumb.getPixel(200, 60);
      expect(center.r, greaterThan(150));
      expect(center.g, lessThan(40));

      await dir.delete(recursive: true);
    },
  );
}
