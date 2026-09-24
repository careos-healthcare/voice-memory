import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';

/// A rectangle around one recognized text block, in image pixels.
class OcrBoundingBox {
  const OcrBoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// One block from an on-device text recognizer.
class OcrTextBlock {
  const OcrTextBlock({
    required this.text,
    required this.bounds,
    required this.confidence,
    this.lines = const [],
  });

  final String text;
  final OcrBoundingBox bounds;

  /// Recognizer score from 0 to 1. Line confidence from the on-device model.
  final double confidence;
  final List<String> lines;
}

/// Full page of text extracted from one image.
class OcrDocument {
  const OcrDocument({required this.text, required this.blocks});

  static const empty = OcrDocument(text: '', blocks: []);

  final String text;
  final List<OcrTextBlock> blocks;

  double get confidence {
    if (blocks.isEmpty) return 0;
    var sum = 0.0;
    for (final block in blocks) {
      sum += block.confidence;
    }
    return sum / blocks.length;
  }
}

/// Fields taken from a `google_mlkit_text_recognition` text block.
///
/// `TextRecognizer.processImage` stays on the device. These values are
/// `TextBlock.text`, `TextBlock.boundingBox`, the line texts, and line
/// confidence. No network client is involved.
class MlKitTextBlock {
  const MlKitTextBlock({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.lines = const [],
    this.confidence,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final List<String> lines;
  final double? confidence;
}

/// Turns ML Kit blocks into the page this app stores.
OcrDocument ocrDocumentFromMlKit({
  required String text,
  required List<MlKitTextBlock> blocks,
}) {
  final parsed = [
    for (final block in blocks)
      OcrTextBlock(
        text: block.text,
        bounds: OcrBoundingBox(
          left: block.left,
          top: block.top,
          right: block.right,
          bottom: block.bottom,
        ),
        confidence: (block.confidence ?? 0).clamp(0, 1).toDouble(),
        lines: block.lines,
      ),
  ];
  final joined = text.trim().isEmpty
      ? parsed.map((block) => block.text).join('\n')
      : text.trim();
  return OcrDocument(text: joined, blocks: parsed);
}

/// Reads text from a photo, handwritten page, or document scan.
///
/// [recognize] is the on-device pass. With photos enabled it should call
/// `TextRecognizer.processImage(InputImage.fromFilePath(path))` from
/// `google_mlkit_text_recognition`. This build keeps
/// [V1CapabilityRegistry.cameraAndPhotos] false, so the plugin stays unlinked
/// and [recognize] runs only when a caller enables it.
class LocalOcrProcessor {
  const LocalOcrProcessor({
    required this.recognize,
    bool? photosEnabled,
  }) : photosEnabled = photosEnabled ?? V1CapabilityRegistry.cameraAndPhotos;

  final Future<OcrDocument> Function(Uint8List imageBytes) recognize;
  final bool photosEnabled;

  Future<OcrDocument> processBytes(Uint8List imageBytes) {
    if (!photosEnabled) return Future<OcrDocument>.value(OcrDocument.empty);
    return recognize(imageBytes);
  }

  Future<OcrDocument> processFile(String path) {
    if (!photosEnabled) return Future<OcrDocument>.value(OcrDocument.empty);
    return recognize(_readFile(path));
  }
}

Uint8List _readFile(String path) => File(path).readAsBytesSync();
