import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as image;

import '../media/encrypted_image_engine.dart';
import '../media/media_attachment.dart';
import 'vision_extraction_models.dart';

abstract interface class VisionLocalExtractor {
  Future<LocalVisionExtraction> extract(MediaAttachment attachment);
}

typedef TextRecognizerFactory = TextRecognizer Function();

/// Performs OCR entirely in memory over a vault-decrypted image.
class MlKitLocalVisionExtractor implements VisionLocalExtractor {
  MlKitLocalVisionExtractor({
    required EncryptedImageEngine imageEngine,
    TextRecognizerFactory? recognizerFactory,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _imageEngine = imageEngine,
       _recognizerFactory = recognizerFactory ?? TextRecognizer.new;

  final EncryptedImageEngine _imageEngine;
  final TextRecognizerFactory _recognizerFactory;

  @override
  Future<LocalVisionExtraction> extract(MediaAttachment attachment) {
    return _imageEngine.withDecryptedFullImage(attachment, (jpegBytes) async {
      final decoded = image.decodeJpg(jpegBytes);
      if (decoded == null) {
        throw const EncryptedImageException(
          'The encrypted image is not a valid JPEG.',
        );
      }
      final oriented = image.bakeOrientation(decoded);
      Uint8List? bitmap;
      TextRecognizer? recognizer;
      try {
        bitmap = oriented.getBytes(order: image.ChannelOrder.bgra);
        final input = InputImage.fromBitmap(
          bitmap: bitmap,
          width: oriented.width,
          height: oriented.height,
        );
        recognizer = _recognizerFactory();
        final recognized = await recognizer.processImage(input);
        final lines = <String>[];
        for (final block in recognized.blocks) {
          for (final line in block.lines) {
            final text = line.text.trim();
            final bounded = text.length > 500 ? text.substring(0, 500) : text;
            if (bounded.isNotEmpty && !lines.contains(bounded)) {
              lines.add(bounded);
            }
          }
        }
        if (lines.isEmpty && recognized.text.trim().isNotEmpty) {
          final text = recognized.text.trim();
          lines.add(text.length > 500 ? text.substring(0, 500) : text);
        }
        return LocalVisionExtraction(
          width: oriented.width,
          height: oriented.height,
          mimeType: attachment.mimeType,
          visibleText: lines.take(100),
          tags: {
            'vision',
            'image',
            'mime:${attachment.mimeType}',
            'dimensions:${oriented.width}x${oriented.height}',
            if (lines.isNotEmpty) 'ocr',
            if (lines.isNotEmpty) 'ocr:text',
          },
        );
      } finally {
        try {
          await recognizer?.close();
        } finally {
          bitmap?.fillRange(0, bitmap.length, 0);
        }
      }
    });
  }
}
