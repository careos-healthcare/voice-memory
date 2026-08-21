// Audits `lib/` for catch blocks that swallow errors without logging, rethrow,
// or returning a failure value.
//
// Run from apps/mobile:
//   dart run tool/audit_silent_catches.dart
//
// Pair with `empty_catches: true` in analysis_options.yaml. Legitimate
// best-effort swallows should carry:
//   // ignore: silent_catch_audit — <reason>
//
// Exit code 1 when unhandled silent catches remain (for CI triage).

import 'dart:io';

const silentCatchAuditRule = 'silent_catch_audit';

void main() {
  final root = _mobileRoot();
  final libDir = Directory('${root.path}/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('Missing lib directory at ${libDir.path}');
    exit(2);
  }

  final legitimate = <String>[];
  final shouldLog = <String>[];

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.contains('/generated/')) continue;
    final findings = _auditFile(entity);
    legitimate.addAll(findings.legitimate);
    shouldLog.addAll(findings.shouldLog);
  }

  if (legitimate.isNotEmpty) {
    stdout.writeln(
      'Legitimate best-effort swallows (${legitimate.length}) — '
      'keep // ignore: $silentCatchAuditRule — reason',
    );
    for (final finding in legitimate) {
      stdout.writeln('  OK  $finding');
    }
    stdout.writeln('');
  }

  if (shouldLog.isEmpty) {
    stdout.writeln('Should-log: none');
    stdout.writeln(
      'OK: no silent catch blocks requiring logging under lib/',
    );
    exit(0);
  }

  stderr.writeln(
    'Should-log (${shouldLog.length}) — route through structured loggers:',
  );
  for (final finding in shouldLog) {
    stderr.writeln('  FIX $finding');
  }
  exit(1);
}

Directory _mobileRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) return cwd;
  final nested = Directory('${cwd.path}/apps/mobile');
  if (File('${nested.path}/pubspec.yaml').existsSync()) return nested;
  stderr.writeln('Run from apps/mobile or repo root.');
  exit(2);
}

class _AuditFindings {
  const _AuditFindings({
    required this.legitimate,
    required this.shouldLog,
  });

  final List<String> legitimate;
  final List<String> shouldLog;
}

_AuditFindings _auditFile(File file) {
  final lines = file.readAsLinesSync();
  final legitimate = <String>[];
  final shouldLog = <String>[];
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (!_isCatchLine(line)) continue;

    final ignoreReason =
        _ignoreReason(line) ?? _ignoreReasonOnPreviousLine(lines, index);
    final body = _catchBody(lines, index);
    if (body.isEmpty) continue;

    final relative = file.path.split('lib/').last;
    final location = 'lib/$relative:${index + 1}';
    final signature = _catchSignature(line);

    if (ignoreReason != null) {
      legitimate.add('$location $signature ($ignoreReason)');
      continue;
    }

    if (_bodyHasObservableAction(body)) continue;

    shouldLog.add('$location $signature');
  }
  return _AuditFindings(legitimate: legitimate, shouldLog: shouldLog);
}

bool _isCatchLine(String line) {
  final trimmed = line.trim();
  if (trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('///')) {
    return false;
  }
  // Match `} catch (` / `on Type catch (` — not prose like "to catch earlier".
  return RegExp(r'(?:\bon\s+\S+\s+)?catch\s*\(').hasMatch(trimmed);
}

String? _ignoreReason(String line) {
  final match = RegExp(
    '//\\s*ignore:\\s*$silentCatchAuditRule(?:\\s*—\\s*(.+))?',
  ).firstMatch(line);
  if (match == null) return null;
  return match.group(1)?.trim() ?? 'documented';
}

String? _ignoreReasonOnPreviousLine(List<String> lines, int catchLineIndex) {
  if (catchLineIndex == 0) return null;
  return _ignoreReason(lines[catchLineIndex - 1]);
}

String _catchSignature(String line) {
  final trimmed = line.trim();
  final withoutLeadingBrace = trimmed.startsWith('}')
      ? trimmed.substring(1).trimLeft()
      : trimmed;
  final head = withoutLeadingBrace.split('{').first.trim();
  return head;
}

List<String> _catchBody(List<String> lines, int catchLineIndex) {
  final buffer = <String>[];
  var depth = 0;
  var started = false;
  for (var index = catchLineIndex; index < lines.length; index++) {
    final line = lines[index];
    if (!started) {
      final brace = line.indexOf('{');
      if (brace == -1) continue;
      started = true;
      depth = 1;
      buffer.add(line.substring(brace + 1));
      if (line.contains('}') && line.indexOf('}') > brace) {
        depth -= line.substring(brace + 1).split('}').length - 1;
      }
      if (depth <= 0) break;
      continue;
    }

    depth += '{'.allMatches(line).length;
    depth -= '}'.allMatches(line).length;
    buffer.add(line);
    if (depth <= 0) break;
  }
  return buffer;
}

bool _bodyHasObservableAction(List<String> body) {
  final text = body.join('\n');
  const markers = [
    'throw ',
    'rethrow',
    'return ',
    'AppLogger.error(',
    'AppLogger.debug(',
    'log(',
    'Log.',
    'Logger.',
    '_logException',
    'errorMessage:',
    'SnackBar',
    'ReleaseLogger.',
    'CapturePipelineLog.',
    'CaptureFlowLog.',
    'JournalSqliteLog.',
    'FcmLog.',
    'BillingAsyncGuardLog.',
    'RevenueCatDiagnosticsLog.',
    'ArchiveLoopRevenueCatLog.',
    'AudioDiagLog.',
    '_setRecordingState',
    '_logRemoteFallback',
    '_uiState =',
    'logAndThrow',
    '_fail(',
    'IsolateWorkerResponse(',
    'LocalDatabaseWorkerResponse(',
    'controller.addError',
    'markFailed(',
    'lastError =',
    '_record(',
    '_failRecoverable',
    '_emit(',
    'setState(',
    'telemetry.',
  ];
  return markers.any(text.contains);
}
