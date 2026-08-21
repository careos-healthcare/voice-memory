// Audits lib/api/models/*_dto.dart for nullable-field annotations and lib/api
// for implicit dynamic usage outside generated parts.
//
// Usage: dart run tool/audit_api_dto_nullability.dart

import 'dart:io';

final _dtoDir = Directory('lib/api/models');
final _apiDir = Directory('lib/api');

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run from apps/mobile');
    exit(1);
  }

  final dtoFiles =
      _dtoDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_dto.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  var nullableFields = 0;
  var annotatedNullable = 0;
  var fieldsWithDefaults = 0;
  var annotatedDefaults = 0;
  final missingAnnotations = <String>[];

  for (final file in dtoFiles) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('final ') || line.contains(' factory ')) {
        continue;
      }

      final fieldLine = line;
      final isNullable = fieldLine.contains('?;') || fieldLine.contains('? ');
      final prevLine = i > 0 ? lines[i - 1].trim() : '';
      final hasJsonKey =
          prevLine.startsWith('@JsonKey') ||
          (i > 1 && lines[i - 2].trim().startsWith('@JsonKey'));

      if (isNullable) {
        nullableFields++;
        if (hasJsonKey) {
          annotatedNullable++;
        } else {
          missingAnnotations.add('${file.path}:$line (nullable, no @JsonKey)');
        }
      }

      if (fieldLine.contains('= const') ||
          fieldLine.contains("= ''") ||
          fieldLine.contains('= false')) {
        fieldsWithDefaults++;
        if (hasJsonKey) {
          annotatedDefaults++;
        }
      }
    }
  }

  stdout.writeln('=== API DTO nullability audit ===');
  stdout.writeln('DTO files scanned: ${dtoFiles.length}');
  stdout.writeln(
    'Nullable fields: $nullableFields (${annotatedNullable} with @JsonKey)',
  );
  stdout.writeln(
    'Constructor-default fields: $fieldsWithDefaults (${annotatedDefaults} with @JsonKey)',
  );

  if (missingAnnotations.isEmpty) {
    stdout.writeln('All nullable DTO fields carry explicit @JsonKey metadata.');
  } else {
    stdout.writeln('\nMissing @JsonKey on nullable fields:');
    for (final item in missingAnnotations) {
      stdout.writeln('  - $item');
    }
  }

  stdout.writeln('\n=== lib/api implicit dynamic scan (non-generated) ===');
  final dynamicHits = <String>[];
  for (final entity in _apiDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    if (entity.path.endsWith('.freezed.dart')) continue;

    final rel = entity.path.replaceFirst('lib/api/', '');
    final content = entity.readAsLinesSync();
    for (var i = 0; i < content.length; i++) {
      final line = content[i];
      if (line.contains('Future<dynamic>') || line.contains('as dynamic')) {
        dynamicHits.add('$rel:${i + 1}: $line');
        continue;
      }
      if (RegExp(r'\bdynamic\b').hasMatch(line) &&
          !line.contains('Map<String, dynamic>') &&
          !line.contains('List<dynamic>')) {
        dynamicHits.add('$rel:${i + 1}: $line');
      }
    }
  }

  if (dynamicHits.isEmpty) {
    stdout.writeln('No Future<dynamic> / as dynamic usage in hand-written lib/api.');
  } else {
    stdout.writeln('Remaining dynamic usages (typed Retrofit backlog):');
    for (final hit in dynamicHits) {
      stdout.writeln('  - $hit');
    }
  }

  exit(missingAnnotations.isEmpty ? 0 : 1);
}