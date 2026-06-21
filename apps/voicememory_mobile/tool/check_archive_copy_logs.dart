import 'dart:io';

import 'package:voicememory_mobile/features/archive_reactivity/archive_log_hygiene.dart';

/// CI-style audit for ArchiveMe logs in test output.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/check_archive_copy_logs.dart <log-file>',
    );
    exit(2);
  }

  final path = args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Log file not found: $path');
    exit(2);
  }

  final lines = file.readAsLinesSync();
  final violations = ArchiveLogHygiene.scanLines(lines);

  if (violations.isEmpty) {
    final archiveMeLineCount = lines
        .where(ArchiveLogHygiene.isRelevantArchiveMeLog)
        .length;
    stdout.writeln(
      'OK: no malformed tokens in ArchiveMe logs '
      '($archiveMeLineCount ARCHIVEME lines scanned, ${lines.length} total)',
    );
    exit(0);
  }

  stderr.writeln(
    'FAIL: found ${violations.length} malformed issue(s) in ArchiveMe logs:',
  );
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  exit(1);
}
