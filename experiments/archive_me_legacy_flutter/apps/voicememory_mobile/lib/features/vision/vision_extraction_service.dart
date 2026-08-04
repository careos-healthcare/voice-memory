import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../api/api_transport.dart';
import '../../security/api_response_safety.dart';
import '../../services/capture_attest_service.dart';
import '../media/encrypted_image_engine.dart';
import '../media/media_attachment.dart';
import 'local_vision_ocr.dart';
import 'vision_extraction_models.dart';

abstract interface class VisionCloudExtractor {
  Future<VisionExtraction> extract({
    required Uint8List imageBytes,
    required String mimeType,
    required String attachmentId,
  });
}

class ApiVisionCloudExtractor implements VisionCloudExtractor {
  ApiVisionCloudExtractor({
    required ApiTransport apiTransport,
    required CaptureAttestService attest,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _transport = apiTransport,
       // ignore: prefer_initializing_formals
       _attest = attest;

  final ApiTransport _transport;
  final CaptureAttestService _attest;

  @override
  Future<VisionExtraction> extract({
    required Uint8List imageBytes,
    required String mimeType,
    required String attachmentId,
  }) async {
    final token = await _attest.ensureCaptureToken();
    final request = http.MultipartRequest(
      'POST',
      _transport.uri('/api/vision-extraction'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      ApiTransport.captureTokenHeader: token,
      'x-vm-client': 'voicememory-mobile',
    });
    final cookie = _transport.sessionCookie;
    if (cookie != null) request.headers['Cookie'] = cookie;
    final mediaType = MediaType.parse(mimeType);
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename:
            '$attachmentId.${mediaType.subtype == 'jpeg' ? 'jpg' : mediaType.subtype}',
        contentType: mediaType,
      ),
    );
    final response = await _transport.send(request);
    ApiResponseSafety.ensureJsonResponse(response);
    return VisionExtraction.fromJson(_transport.decodeJson(response));
  }
}

class VisionExtractionService {
  VisionExtractionService({
    required EncryptedImageEngine imageEngine,
    required VisionLocalExtractor localExtractor,
    VisionCloudExtractor? cloudExtractor,
    ApiTransport? apiTransport,
    CaptureAttestService? attest,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _imageEngine = imageEngine,
       // ignore: prefer_initializing_formals
       _localExtractor = localExtractor,
       _cloudExtractor =
           cloudExtractor ??
           ApiVisionCloudExtractor(
             apiTransport: apiTransport!,
             attest: attest!,
           );

  factory VisionExtractionService.production({
    required EncryptedImageEngine imageEngine,
    required ApiTransport apiTransport,
    required CaptureAttestService attest,
  }) {
    return VisionExtractionService(
      imageEngine: imageEngine,
      localExtractor: MlKitLocalVisionExtractor(imageEngine: imageEngine),
      apiTransport: apiTransport,
      attest: attest,
    );
  }

  final EncryptedImageEngine _imageEngine;
  final VisionLocalExtractor _localExtractor;
  final VisionCloudExtractor _cloudExtractor;

  /// Local OCR always completes first. Any cloud or response-contract failure
  /// returns the local extraction instead of losing the visual memory.
  Future<VisionExtractionResult> extract(MediaAttachment attachment) async {
    final local = await _localExtractor.extract(attachment);
    try {
      final cloud = await _imageEngine.withDecryptedFullImage(
        attachment,
        (bytes) => _cloudExtractor.extract(
          imageBytes: bytes,
          mimeType: attachment.mimeType,
          attachmentId: attachment.id,
        ),
      );
      return VisionExtractionResult(
        local: local,
        extraction: cloud,
        usedCloud: true,
      );
    } on Object {
      return VisionExtractionResult(
        local: local,
        extraction: local.asLocalOnlyExtraction(),
        usedCloud: false,
      );
    }
  }
}
