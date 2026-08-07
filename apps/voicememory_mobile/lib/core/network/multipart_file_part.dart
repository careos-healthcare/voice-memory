import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// One file part for [HttpTransport.postMultipart].
sealed class MultipartFilePart {
  const MultipartFilePart._({
    required this.field,
    this.filename,
    this.contentType,
  });

  final String field;
  final String? filename;
  final MediaType? contentType;

  factory MultipartFilePart.fromPath({
    required String field,
    required String path,
    String? filename,
    MediaType? contentType,
  }) {
    return _PathMultipartFilePart(
      field: field,
      path: path,
      filename: filename,
      contentType: contentType,
    );
  }

  factory MultipartFilePart.fromBytes({
    required String field,
    required List<int> bytes,
    String? filename,
    MediaType? contentType,
  }) {
    return _BytesMultipartFilePart(
      field: field,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
  }

  factory MultipartFilePart.fromStream({
    required String field,
    required Stream<List<int>> stream,
    required int length,
    String? filename,
    MediaType? contentType,
  }) {
    return _StreamMultipartFilePart(
      field: field,
      stream: stream,
      length: length,
      filename: filename,
      contentType: contentType,
    );
  }

  Future<http.MultipartFile> toMultipartFile() {
    return switch (this) {
      _PathMultipartFilePart(:final path) => http.MultipartFile.fromPath(
        field,
        path,
        filename: filename,
        contentType: contentType,
      ),
      _BytesMultipartFilePart(:final bytes) => Future.value(
        http.MultipartFile.fromBytes(
          field,
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      ),
      _StreamMultipartFilePart(:final stream, :final length) => Future.value(
        http.MultipartFile(
          field,
          stream,
          length,
          filename: filename,
          contentType: contentType,
        ),
      ),
    };
  }
}

final class _PathMultipartFilePart extends MultipartFilePart {
  const _PathMultipartFilePart({
    required super.field,
    required this.path,
    super.filename,
    super.contentType,
  }) : super._();

  final String path;
}

final class _BytesMultipartFilePart extends MultipartFilePart {
  const _BytesMultipartFilePart({
    required super.field,
    required this.bytes,
    super.filename,
    super.contentType,
  }) : super._();

  final List<int> bytes;
}

final class _StreamMultipartFilePart extends MultipartFilePart {
  const _StreamMultipartFilePart({
    required super.field,
    required this.stream,
    required this.length,
    super.filename,
    super.contentType,
  }) : super._();

  final Stream<List<int>> stream;
  final int length;
}
