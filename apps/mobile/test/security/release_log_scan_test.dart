import 'dart:io';

import 'package:archiveme_mobile/security/privacy_log_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/prohibited_log_examples.dart';

void main() {
  test('mobile privacy log validator passes on production graph', () {
    final result = Process.runSync(
      'dart',
      ['run', 'tool/validate_mobile_privacy_logs.dart'],
      workingDirectory: Directory.current.path,
    );
    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout.toString(), contains('validate_mobile_privacy_logs: PASS'));
  });

  test('record and transcription logs route through ReleaseLogger', () {
    final recordLog = File('lib/services/record_pipeline_log.dart').readAsStringSync();
    final transcriptionLog = File(
      'lib/features/voice_capture/transcription/transcription_log.dart',
    ).readAsStringSync();

    expect(recordLog, contains('ReleaseLogger.emit'));
    expect(recordLog, isNot(contains("log('audio file path=")));
    expect(transcriptionLog, isNot(contains('audioPath=\$audioPath')));
    expect(transcriptionLog, contains('ReleaseLogger'));
  });

  test('validator detects injected prohibited log fragments', () {
    final failures = PrivacyLogValidator.scanSource(
      path: 'lib/services/injected_bad_log.dart',
      lines: ["  debugPrint('audioPath=/secret/path.m4a');"],
    );
    expect(failures, isNotEmpty);
    expect(failures.single, contains('audioPath='));
  });

  test('validator fixture file excludes marked prohibited examples', () {
    final fixturePath = 'test/security/fixtures/prohibited_log_examples.dart';
    final lines = File(fixturePath).readAsLinesSync();
    final failures = PrivacyLogValidator.scanSource(
      path: fixturePath,
      lines: lines,
    );
    expect(failures, isEmpty);
    expect(
      ProhibitedLogFixtureExamples.examples.join('\n'),
      contains('audioPath='),
    );
  });

  test('production graph scan skips test fixture paths', () {
    final root = Directory.current.path;
    final failures = PrivacyLogValidator.validateProductionGraph(root);
    expect(
      failures.where((f) => f.contains('prohibited_log_examples.dart')),
      isEmpty,
    );
  });
}
