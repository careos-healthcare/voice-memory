import 'dart:io';

/// Recursively exports [apps/mobile/lib] source into three evenly sized parts on
/// the desktop for upload.
///
/// Run from apps/mobile:
///   dart run tool/upload1_lib_export.dart
void main() {
  final mobileRoot = _resolveMobileRoot();
  final libRoot = Directory('${mobileRoot.path}/lib');
  if (!libRoot.existsSync()) {
    stderr.writeln('Missing lib directory: ${libRoot.path}');
    exit(1);
  }

  final outputDir = Directory('${Platform.environment['HOME']}/Desktop/upload1');
  outputDir.createSync(recursive: true);

  final sections = _collectSections(libRoot);
  if (sections.isEmpty) {
    stderr.writeln('No source files found under ${libRoot.path}');
    exit(1);
  }

  final parts = _distributeEvenly(sections, partCount: 3);
  final outputNames = [
    'upload1_part1.txt',
    'upload1_part2.txt',
    'upload1_part3.txt',
  ];

  for (var index = 0; index < outputNames.length; index++) {
    final partSections = parts[index];
    final buffer = StringBuffer()
      ..writeln(_partHeader(
        partNumber: index + 1,
        partCount: outputNames.length,
        sectionCount: partSections.length,
        libRoot: libRoot,
      ));

    for (final section in partSections) {
      buffer.write(section.formattedText);
    }

    final outputFile = File('${outputDir.path}/${outputNames[index]}');
    outputFile.writeAsStringSync(buffer.toString());
    stdout.writeln(
      'Wrote ${outputFile.path} '
      '(${partSections.length} files, ${outputFile.lengthSync()} bytes)',
    );
  }

  stdout.writeln(
    'Done: exported ${sections.length} files from ${libRoot.path} '
    'to ${outputDir.path}',
  );
}

Directory _resolveMobileRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) {
    return cwd;
  }
  final nested = Directory('${cwd.path}/apps/mobile');
  if (File('${nested.path}/pubspec.yaml').existsSync()) {
    return nested;
  }
  stderr.writeln(
    'Run from apps/mobile or repo root (pubspec.yaml not found).',
  );
  exit(1);
}

class _ExportSection {
  const _ExportSection({
    required this.displayPath,
    required this.content,
  });

  final String displayPath;
  final String content;

  int get byteLength => formattedText.length;

  String get formattedText =>
      _fileHeader(displayPath) + content;
}

String _partHeader({
  required int partNumber,
  required int partCount,
  required int sectionCount,
  required Directory libRoot,
}) {
  final timestamp = DateTime.now().toUtc().toIso8601String();
  return '''
${'=' * 80}
ArchiveMe mobile lib export — part $partNumber of $partCount
Generated: $timestamp
Source root: ${libRoot.path}
Files in this part: $sectionCount
${'=' * 80}

''';
}

String _fileHeader(String displayPath) {
  return '''

${'=' * 80}
FILE: $displayPath
${'=' * 80}

''';
}

List<_ExportSection> _collectSections(Directory libRoot) {
  final files = libRoot
      .listSync(recursive: true)
      .whereType<File>()
      .where(_isSourceFile)
      .toList()
    ..sort((a, b) => _relativePath(libRoot, a).compareTo(_relativePath(libRoot, b)));

  return [
    for (final file in files)
      _ExportSection(
        displayPath: _displayPath(mobileRoot: libRoot.parent, libRoot: libRoot, file: file),
        content: file.readAsStringSync(),
      ),
  ];
}

String _displayPath({
  required Directory mobileRoot,
  required Directory libRoot,
  required File file,
}) {
  final fromLib = _relativePath(libRoot, file);
  final mobilePath = mobileRoot.path.replaceAll('\\', '/');
  if (mobilePath.endsWith('/apps/mobile') || mobilePath.endsWith('apps/mobile')) {
    return 'apps/mobile/lib/$fromLib';
  }
  final mobileSegment = mobileRoot.path.split(Platform.pathSeparator).last;
  return '$mobileSegment/lib/$fromLib';
}

bool _isSourceFile(File file) {
  final path = file.path;
  if (!path.endsWith('.dart')) return false;
  return true;
}

String _relativePath(Directory libRoot, File file) {
  return file.path.substring(libRoot.path.length + 1);
}

List<List<_ExportSection>> _distributeEvenly(
  List<_ExportSection> sections, {
  required int partCount,
}) {
  final parts = List.generate(partCount, (_) => <_ExportSection>[]);
  final partSizes = List<int>.filled(partCount, 0);

  for (final section in sections) {
    var targetIndex = 0;
    for (var index = 1; index < partCount; index++) {
      if (partSizes[index] < partSizes[targetIndex]) {
        targetIndex = index;
      }
    }
    parts[targetIndex].add(section);
    partSizes[targetIndex] += section.byteLength;
  }

  return parts;
}
