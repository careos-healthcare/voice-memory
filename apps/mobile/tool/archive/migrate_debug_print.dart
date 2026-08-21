import 'dart:io';

/// Replaces every `debugPrint(` in lib/ with `AppLogger.debug(` and adds the
/// app_logger import where missing.
///
/// Run from apps/mobile:
///   dart run tool/migrate_debug_print.dart
void main() {
  final mobileRoot = _resolveMobileRoot();
  final libDir = Directory('${mobileRoot.path}/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('Missing lib directory: ${libDir.path}');
    exit(1);
  }

  const importLine =
      "import 'package:archiveme_mobile/core/utils/app_logger.dart';";

  var modified = 0;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('${Platform.pathSeparator}app_logger.dart')) {
      continue;
    }

    final original = entity.readAsStringSync();
    if (!original.contains('debugPrint(')) continue;

    var updated = original.replaceAll('debugPrint(', 'AppLogger.debug(');
    if (!updated.contains('app_logger.dart')) {
      updated = _insertImport(updated, importLine);
    }

    entity.writeAsStringSync(updated);
    modified++;
    stdout.writeln('Modified: ${entity.path}');
  }

  stdout.writeln('Done: migrated debugPrint in $modified files.');
}

Directory _resolveMobileRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) return cwd;
  final nested = Directory('${cwd.path}/apps/mobile');
  if (File('${nested.path}/pubspec.yaml').existsSync()) return nested;
  stderr.writeln('Run from apps/mobile or repo root.');
  exit(1);
}

String _insertImport(String content, String importLine) {
  final lines = content.split('\n');
  var firstImport = -1;
  var lastImport = -1;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('import ')) {
      firstImport = firstImport == -1 ? i : firstImport;
      lastImport = i;
    } else if (lastImport >= 0 && line.trim().isNotEmpty) {
      break;
    }
  }

  if (firstImport == -1) {
    return '$importLine\n$content';
  }

  var insertAt = lastImport + 1;
  for (var i = firstImport; i <= lastImport; i++) {
    if (lines[i].compareTo(importLine) > 0) {
      insertAt = i;
      break;
    }
  }

  lines.insert(insertAt, importLine);
  return lines.join('\n');
}
