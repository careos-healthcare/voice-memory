import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/vision/image_embedding_inference.dart';
import 'package:archiveme_mobile/features/vision/image_processor.dart';

/// Deterministic on-device visual projection — no network, no model asset.
///
/// Pools the 224×224 NCHW tensor into a 14×14 grid per channel, then projects
/// through a fixed weight matrix (seeded PRNG) to [imageEmbeddingDimensions].
class LocalVisualProjectionInference implements ImageEmbeddingInference {
  LocalVisualProjectionInference({math.Random? random})
      : _random = random ?? math.Random(_seed);

  static const _seed = 0x764953;
  static const _poolStride = 16;
  static const _gridSize = ImageProcessor.inputSize ~/ _poolStride;

  final math.Random _random;
  late final List<List<double>> _weights = _buildProjectionWeights();

  static int get featureCount => _gridSize * _gridSize * ImageProcessor.channelCount;

  @override
  Future<List<double>> embed(Float32List nchwTensor) async {
    if (nchwTensor.length != ImageProcessor.tensorElementCount) {
      throw ArgumentError.value(
        nchwTensor.length,
        'nchwTensor.length',
        'expected ${ImageProcessor.tensorElementCount}',
      );
    }

    final features = _poolFeatures(nchwTensor);
    final embedding = List<double>.filled(imageEmbeddingDimensions, 0);

    for (var dim = 0; dim < imageEmbeddingDimensions; dim++) {
      var sum = 0.0;
      final row = _weights[dim];
      for (var feature = 0; feature < features.length; feature++) {
        sum += row[feature] * features[feature];
      }
      embedding[dim] = sum;
    }

    return ImageProcessor.l2Normalize(embedding);
  }

  List<double> _poolFeatures(Float32List nchwTensor) {
    final planeSize = ImageProcessor.inputSize * ImageProcessor.inputSize;
    final features = List<double>.filled(featureCount, 0);
    var featureIndex = 0;

    for (var channel = 0; channel < ImageProcessor.channelCount; channel++) {
      final channelOffset = channel * planeSize;
      for (var gridY = 0; gridY < _gridSize; gridY++) {
        for (var gridX = 0; gridX < _gridSize; gridX++) {
          var sum = 0.0;
          var count = 0;
          final startY = gridY * _poolStride;
          final startX = gridX * _poolStride;
          for (var y = 0; y < _poolStride; y++) {
            for (var x = 0; x < _poolStride; x++) {
              final pixelY = startY + y;
              final pixelX = startX + x;
              if (pixelY >= ImageProcessor.inputSize ||
                  pixelX >= ImageProcessor.inputSize) {
                continue;
              }
              final index = channelOffset + (pixelY * ImageProcessor.inputSize) + pixelX;
              sum += nchwTensor[index];
              count++;
            }
          }
          features[featureIndex++] = count == 0 ? 0 : sum / count;
        }
      }
    }

    return features;
  }

  List<List<double>> _buildProjectionWeights() {
    return List.generate(imageEmbeddingDimensions, (_) {
      return List.generate(featureCount, (_) {
        return (_random.nextDouble() * 2) - 1;
      }, growable: false);
    }, growable: false);
  }
}
