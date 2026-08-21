// Unified sweep: debugPrint → AppLogger.debug, catch signature hardening, bare-catch logging.
//
// Run from apps/mobile:
//   dart run tool/sweep_logging_and_catches.dart

import 'dart:io';

void main() async {
  final mobileRoot = _resolveMobileRoot();
  stdout.writeln('==> debugPrint migration');
  final migrate = await Process.run(
    'dart',
    ['run', 'tool/migrate_debug_print.dart'],
    workingDirectory: mobileRoot.path,
  );
  stdout.write(migrate.stdout);
  stderr.write(migrate.stderr);
  if (migrate.exitCode != 0) exit(migrate.exitCode);

  stdout.writeln('==> catch block hardening');
  final refactor = await Process.run(
    'dart',
    ['run', 'tool/refactor_catch_blocks.dart'],
    workingDirectory: mobileRoot.path,
  );
  stdout.write(refactor.stdout);
  stderr.write(refactor.stderr);
  if (refactor.exitCode != 0) exit(refactor.exitCode);

  stdout.writeln('==> silent catch audit');
  final audit = await Process.run(
    'dart',
    ['run', 'tool/audit_silent_catches.dart'],
    workingDirectory: mobileRoot.path,
  );
  stdout.write(audit.stdout);
  stderr.write(audit.stderr);
  exit(audit.exitCode);
}

Directory _resolveMobileRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) return cwd;
  final nested = Directory('${cwd.path}/apps/mobile');
  if (File('${nested.path}/pubspec.yaml').existsSync()) return nested;
  stderr.writeln('Run from apps/mobile or repo root.');
  exit(1);
}
