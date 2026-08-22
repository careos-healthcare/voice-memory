import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// On-device preprocessing for vision encoder models (224×224, ImageNet norm).
class ImageProcessor {
  const ImageProcessor();

  static const inputSize = 224;
  static const channelCount = 3;
  static const batchSize = 1;

  /// ImageNet mean / std — matches CLIP and MobileCLIP preprocessing.
  static const meanR = 0.485;
  static const meanG = 0.456;
  static const meanB = 0.406;
  static const stdR = 0.229;
  static const stdG = 0.224;
  static const stdB = 0.225;

  /// Expected float count for NCHW `[1, 3, 224, 224]`.
  static int get tensorElementCount =>
      batchSize * channelCount * inputSize * inputSize;

  /// Decodes [imageBytes], resizes to 224×224, normalizes, returns NCHW tensor.
  Float32List prepareModelInput(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw FormatException('Could not decode image (${imageBytes.length} bytes)');
    }

    final resized = img.copyResize(
      decoded,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    return _toNormalizedNchw(resized);
  }

  Float32List _toNormalizedNchw(img.Image image) {
    final tensor = Float32List(tensorElementCount);
    final planeSize = inputSize * inputSize;

    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final index = y * inputSize + x;
        tensor[index] = (r - meanR) / stdR;
        tensor[planeSize + index] = (g - meanG) / stdG;
        tensor[(2 * planeSize) + index] = (b - meanB) / stdB;
      }
    }

    return tensor;
  }

  /// L2-normalizes a vector in-place copy.
  static List<double> l2Normalize(List<double> vector) {
    var norm = 0.0;
    for (final value in vector) {
      norm += value * value;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return List<double>.from(vector);
    return vector.map((value) => value / norm).toList(growable: false);
  }
}
