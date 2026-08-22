import 'dart:typed_data';

import 'package:archiveme_mobile/features/vision/image_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _solidPng(int width, int height, int r, int g, int b) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('ImageProcessor', () {
    const processor = ImageProcessor();

    test('prepareModelInput returns 224x224 NCHW tensor', () {
      final bytes = _solidPng(480, 320, 200, 40, 10);
      final tensor = processor.prepareModelInput(bytes);

      expect(tensor.length, ImageProcessor.tensorElementCount);
      expect(tensor.length, 1 * 3 * 224 * 224);
    });

    test('normalizes red channel with ImageNet mean/std', () {
      final bytes = _solidPng(64, 64, 255, 0, 0);
      final tensor = processor.prepareModelInput(bytes);

      final expected = (1.0 - ImageProcessor.meanR) / ImageProcessor.stdR;
      expect(tensor[0], closeTo(expected, 0.01));
    });

    test('l2Normalize produces unit length', () {
      final normalized = ImageProcessor.l2Normalize([3, 4]);
      final norm = normalized.fold<double>(0, (sum, value) => sum + value * value);
      expect(norm, closeTo(1, 1e-9));
    });
  });
}
