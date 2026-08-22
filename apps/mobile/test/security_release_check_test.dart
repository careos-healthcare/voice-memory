import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('security_release_check passes on clean tree', () {
    final result = Process.runSync(
      'dart',
      ['run', 'tool/security_release_check.dart'],
      runInShell: true,
      workingDirectory: Directory.current.path,
    );
    expect(
      result.exitCode,
      0,
      reason: result.stderr.toString().isEmpty
          ? result.stdout.toString()
          : '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout.toString(), contains('security_release_check: PASS'));
  });
}