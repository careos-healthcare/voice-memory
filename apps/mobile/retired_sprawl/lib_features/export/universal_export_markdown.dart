import 'dart:convert';

import 'package:archiveme_mobile/features/export/universal_export_models.dart';

/// Markdown and audio sidecar text for one exported moment.
abstract final class UniversalExportMarkdown {
  static String document(UniversalExportEntry entry) {
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('id: ${_quote(entry.id)}')
      ..writeln('createdAt: ${_quote(entry.createdAt.toUtc().toIso8601String())}')
      ..writeln(
        'updatedAt: ${_quote((entry.updatedAt ?? entry.createdAt).toUtc().toIso8601String())}',
      );
    if (entry.tags.isEmpty) {
      buffer.writeln('tags: []');
    } else {
      buffer.writeln('tags:');
      for (final tag in entry.tags) {
        buffer.writeln('  - ${_quote(tag)}');
      }
    }
    buffer.writeln('location: ${_quote(entry.location)}');
    final metadata = entry.metadata;
    if (metadata.isEmpty) {
      buffer.writeln('metadata: {}');
    } else {
      buffer.writeln('metadata:');
      for (final key in metadata.keys) {
        buffer.writeln('  ${_yamlKey(key)}: ${_yamlValue(metadata[key])}');
      }
    }
    buffer
      ..writeln('---')
      ..writeln()
      ..write(entry.transcript);
    return buffer.toString();
  }

  static String sidecar(UniversalExportEntry entry, {required int bytes}) {
    return jsonEncode({
      'entryId': entry.id,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'updatedAt': (entry.updatedAt ?? entry.createdAt).toUtc().toIso8601String(),
      'location': entry.location,
      'tags': entry.tags,
      'bytes': bytes,
      'format': _format(entry.audioPath),
      'metadata': entry.metadata,
    });
  }

  static bool isRawRecording(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.wav') || lower.endsWith('.m4a');
  }

  static String _format(String? path) {
    final lower = path?.toLowerCase() ?? '';
    if (lower.endsWith('.wav')) return 'wav';
    if (lower.endsWith('.m4a')) return 'm4a';
    return '';
  }

  static String _quote(String value) {
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }

  static String _yamlKey(String key) {
    return RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key) ? key : _quote(key);
  }

  static String _yamlValue(Object? value) {
    if (value == null) return '""';
    if (value is num || value is bool) return '$value';
    return _quote('$value');
  }
}

/// Short label for an uncompressed byte count.
String formatExportBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
