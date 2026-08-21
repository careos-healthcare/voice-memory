import 'dart:io';

/// Refactors catch blocks under lib/:
/// - Adds `stackTrace` to catch signatures
/// - Logs empty / comment-only swallows via [AppLogger.error]
/// - Preserves documented best-effort swallows and existing recovery logic
///
/// Run from apps/mobile:
///   dart run tool/refactor_catch_blocks.dart
void main() {
  final mobileRoot = _resolveMobileRoot();
  final libDir = Directory('${mobileRoot.path}/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('Missing lib directory: ${libDir.path}');
    exit(1);
  }

  const importLine =
      "import 'package:archiveme_mobile/core/utils/app_logger.dart';";

  var filesModified = 0;
  var signaturesUpgraded = 0;
  var logsAdded = 0;

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (_isGenerated(entity.path)) continue;

    final original = entity.readAsLinesSync();
    final result = _refactorLines(original);
    if (result.signaturesUpgraded == 0 && result.logsAdded == 0) continue;

    var output = result.lines.join('\n');
    if (result.logsAdded > 0 && !output.contains('app_logger.dart')) {
      output = _insertImport(output, importLine);
    }

    entity.writeAsStringSync(output);
    filesModified++;
    signaturesUpgraded += result.signaturesUpgraded;
    logsAdded += result.logsAdded;
    stdout.writeln(
      'Modified ${entity.path}: '
      '${result.signaturesUpgraded} signatures, ${result.logsAdded} logs',
    );
  }

  stdout.writeln(
    'Done: $filesModified files, '
    '$signaturesUpgraded signatures upgraded, $logsAdded error logs added.',
  );
}

class _RefactorResult {
  const _RefactorResult({
    required this.lines,
    required this.signaturesUpgraded,
    required this.logsAdded,
  });

  final List<String> lines;
  final int signaturesUpgraded;
  final int logsAdded;
}

Directory _resolveMobileRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) return cwd;
  final nested = Directory('${cwd.path}/apps/mobile');
  if (File('${nested.path}/pubspec.yaml').existsSync()) return nested;
  stderr.writeln('Run from apps/mobile or repo root.');
  exit(1);
}

bool _isGenerated(String path) {
  return path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.contains('/generated/');
}

_RefactorResult _refactorLines(List<String> lines) {
  final blocks = _findCatchBlocks(lines);
  if (blocks.isEmpty) {
    return _RefactorResult(lines: lines, signaturesUpgraded: 0, logsAdded: 0);
  }

  final mutable = List<String>.from(lines);
  var signaturesUpgraded = 0;
  var logsAdded = 0;

  for (final block in blocks.reversed) {
    final outcome = _refactorCatchBlock(mutable, block);
    signaturesUpgraded += outcome.signaturesUpgraded;
    logsAdded += outcome.logsAdded;
  }

  return _RefactorResult(
    lines: mutable,
    signaturesUpgraded: signaturesUpgraded,
    logsAdded: logsAdded,
  );
}

class _CatchBlock {
  const _CatchBlock({
    required this.catchLineIndex,
    required this.bodyStartIndex,
    required this.bodyEndIndex,
  });

  final int catchLineIndex;
  final int bodyStartIndex;
  final int bodyEndIndex;
}

class _BlockOutcome {
  const _BlockOutcome({
    required this.signaturesUpgraded,
    required this.logsAdded,
  });

  final int signaturesUpgraded;
  final int logsAdded;
}

List<_CatchBlock> _findCatchBlocks(List<String> lines) {
  final blocks = <_CatchBlock>[];
  for (var index = 0; index < lines.length; index++) {
    if (!_isCatchLine(lines[index])) continue;
    final body = _catchBodyRange(lines, index);
    if (body == null) continue;
    blocks.add(
      _CatchBlock(
        catchLineIndex: index,
        bodyStartIndex: body.start,
        bodyEndIndex: body.end,
      ),
    );
  }
  return blocks;
}

class _BodyRange {
  const _BodyRange({required this.start, required this.end});
  final int start;
  final int end;
}

bool _isCatchLine(String line) => RegExp(r'\bcatch\b\s*\(').hasMatch(line);

_BodyRange? _catchBodyRange(List<String> lines, int catchLineIndex) {
  var depth = 0;
  var started = false;
  int? bodyStart;
  for (var index = catchLineIndex; index < lines.length; index++) {
    final line = lines[index];
    if (!started) {
      final brace = line.indexOf('{');
      if (brace == -1) continue;
      started = true;
      depth = 1;
      bodyStart = index;
      final afterBrace = line.substring(brace + 1);
      depth += '{'.allMatches(afterBrace).length;
      depth -= '}'.allMatches(afterBrace).length;
      if (depth <= 0) return _BodyRange(start: bodyStart, end: index);
      continue;
    }

    depth += '{'.allMatches(line).length;
    depth -= '}'.allMatches(line).length;
    if (depth <= 0) {
      return _BodyRange(start: bodyStart!, end: index);
    }
  }
  return null;
}

_BlockOutcome _refactorCatchBlock(List<String> lines, _CatchBlock block) {
  var signaturesUpgraded = 0;
  var logsAdded = 0;

  final catchLine = lines[block.catchLineIndex];
  final upgradedCatchLine = _upgradeCatchSignature(catchLine);
  if (upgradedCatchLine != catchLine) {
    lines[block.catchLineIndex] = upgradedCatchLine;
    signaturesUpgraded++;
  }

  final bodyLines = lines.sublist(block.bodyStartIndex, block.bodyEndIndex + 1);
  final ignoreReason = _ignoreReason(catchLine) ??
      (block.catchLineIndex > 0
          ? _ignoreReason(lines[block.catchLineIndex - 1])
          : null);

  final catchVar = _catchVariableName(upgradedCatchLine) ?? 'e';
  final shouldAddLog = _shouldAddErrorLog(bodyLines, ignoreReason);

  if (shouldAddLog) {
    final indent = _bodyIndent(bodyLines, block.catchLineIndex, lines);
    final logLine =
        "${indent}AppLogger.error('Unhandled error caught', "
        'error: $catchVar, stackTrace: stackTrace);';

    if (_isInlineEmptyCatch(bodyLines)) {
      final line = lines[block.catchLineIndex];
      lines[block.catchLineIndex] = line.replaceFirst(
        RegExp(r'\{\s*\}\s*$'),
        '{\n$logLine\n$indent}',
      );
      if (_catchVariableName(lines[block.catchLineIndex]) == '_') {
        lines[block.catchLineIndex] = lines[block.catchLineIndex]
            .replaceFirst('catch (_,', 'catch (e,');
      }
    } else {
      final insertAt = _logInsertIndex(bodyLines, block.bodyStartIndex);
      lines.insert(insertAt, logLine);
    }
    logsAdded++;
  } else {
    final enhanced = _enhanceLoggingWithStackTrace(bodyLines, catchVar);
    if (enhanced != bodyLines) {
      lines.replaceRange(
        block.bodyStartIndex,
        block.bodyEndIndex + 1,
        enhanced,
      );
    }
  }

  return _BlockOutcome(
    signaturesUpgraded: signaturesUpgraded,
    logsAdded: logsAdded,
  );
}

String _upgradeCatchSignature(String line) {
  final withStack = RegExp(r'catch\s*\(\s*(\w+)\s*,\s*(\w+)\s*\)');
  final existing = withStack.firstMatch(line);
  if (existing != null) {
    final stackParam = existing.group(2)!;
    if (stackParam == 'stackTrace') return line;
    return line.replaceFirst(
      'catch (${existing.group(1)}, $stackParam)',
      'catch (${existing.group(1)}, stackTrace)',
    );
  }

  return line.replaceAllMapped(
    RegExp(r'catch\s*\(\s*(\w+)\s*\)'),
    (match) => 'catch (${match.group(1)}, stackTrace)',
  );
}

String? _catchVariableName(String catchLine) {
  final match = RegExp(r'catch\s*\(\s*(\w+)').firstMatch(catchLine);
  return match?.group(1);
}

String? _ignoreReason(String line) {
  final match = RegExp(
    r'//\s*ignore:\s*silent_catch_audit(?:\s*—\s*(.+))?',
  ).firstMatch(line);
  if (match == null) return null;
  return match.group(1)?.trim() ?? 'documented';
}

bool _shouldAddErrorLog(List<String> bodyLines, String? ignoreReason) {
  if (ignoreReason != null) return false;
  if (_isEmptyOrCommentOnly(bodyLines)) return true;
  return _isDebugOnlyBody(bodyLines);
}

bool _isDebugOnlyBody(List<String> bodyLines) {
  final inner = _extractCatchBodyInner(bodyLines);
  var hasDebug = false;
  for (final line in inner.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('//')) continue;
    if (trimmed.contains('AppLogger.debug(') ||
        trimmed.contains('debugPrint(')) {
      hasDebug = true;
      continue;
    }
    if (trimmed.contains('AppLogger.error(')) return false;
    return false;
  }
  return hasDebug;
}

bool _isEmptyOrCommentOnly(List<String> bodyLines) {
  final inner = _extractCatchBodyInner(bodyLines);
  for (final line in inner.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('//')) continue;
    return false;
  }
  return true;
}

String _extractCatchBodyInner(List<String> bodyLines) {
  final text = bodyLines.join('\n');
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) return text;
  return text.substring(start + 1, end);
}

bool _isInlineEmptyCatch(List<String> bodyLines) {
  if (bodyLines.length != 1) return false;
  return RegExp(r'\{\s*\}\s*$').hasMatch(bodyLines.first);
}

String _bodyIndent(
  List<String> bodyLines,
  int catchLineIndex,
  List<String> allLines,
) {
  final catchLine = allLines[catchLineIndex];
  final leading = RegExp(r'^(\s*)').firstMatch(catchLine)?.group(1) ?? '';
  return '$leading  ';
}

int _logInsertIndex(List<String> bodyLines, int bodyStartIndex) {
  if (bodyLines.isEmpty) return bodyStartIndex + 1;
  final first = bodyLines.first;
  if (first.contains('{') && !RegExp(r'\{\s*\}').hasMatch(first)) {
    return bodyStartIndex + 1;
  }
  return bodyStartIndex + 1;
}

List<String> _enhanceLoggingWithStackTrace(
  List<String> bodyLines,
  String catchVar,
) {
  final updated = <String>[];
  var changed = false;

  for (final line in bodyLines) {
    var next = line;
    if (_isLoggingCall(next) &&
        _lineHasErrorArg(next) &&
        !_lineHasStackTraceArg(next)) {
      final enhanced = _appendStackTraceArg(next, catchVar);
      if (enhanced != next) {
        next = enhanced;
        changed = true;
      }
    }
    updated.add(next);
  }

  return changed ? updated : bodyLines;
}

bool _isLoggingCall(String line) {
  const markers = [
    'AppLogger.',
    'debugPrint(',
    'Log.',
    'Logger.',
    'FcmLog.',
    'BillingAsyncGuardLog.',
    'RevenueCatDiagnosticsLog.',
    'CapturePipelineLog.',
    'CaptureFlowLog.',
    'JournalSqliteLog.',
    'AudioDiagLog.',
    'RecordPipelineLog.',
    'ReleaseLogger.',
  ];
  return markers.any(line.contains);
}

bool _lineHasErrorArg(String line) =>
    RegExp(r'\berror:\s*\w+').hasMatch(line);

bool _lineHasStackTraceArg(String line) =>
    RegExp(r'\bstackTrace:\s*\w+').hasMatch(line);

String _appendStackTraceArg(String line, String catchVar) {
  if (_lineHasStackTraceArg(line)) return line;

  final errorMatch = RegExp(r'error:\s*(\w+)').firstMatch(line);
  if (errorMatch == null) return line;

  final errorVar = errorMatch.group(1)!;
  final insertPoint = line.indexOf('error: $errorVar') + 'error: $errorVar'.length;
  return '${line.substring(0, insertPoint)}, '
      'stackTrace: stackTrace${line.substring(insertPoint)}';
}

String _insertImport(String content, String importLine) {
  final lines = content.split('\n');
  var firstImport = -1;
  var lastImport = -1;

  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('import ')) {
      firstImport = firstImport == -1 ? i : firstImport;
      lastImport = i;
    } else if (lastImport >= 0 && lines[i].trim().isNotEmpty) {
      break;
    }
  }

  if (firstImport == -1) return '$importLine\n$content';

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
