import 'dart:io';

/// Static analysis for release-safe logging on the focused beta production graph.
abstract final class PrivacyLogValidator {
  PrivacyLogValidator._();

  static const fixtureMarker = 'PRIVACY_LOG_VALIDATOR_FIXTURE';

  static const scanRoots = [
    'lib/services',
    'lib/features/voice_capture',
    'lib/features/recording',
    'lib/features/sync',
    'lib/features/auth',
    'lib/security',
    'lib/data/network',
    'lib/audio',
    'lib/startup',
    'lib/billing',
    'lib/features/billing',
    'lib/screens',
  ];

  static const approvedLogWrappers = {
    'release_logger.dart',
    'release_log_sanitizer.dart',
    'record_pipeline_log.dart',
    'transcription_log.dart',
    'analysis_log.dart',
    'audio_diag_log.dart',
    'product_analytics.dart',
    'proof_analytics_guard.dart',
    'validate_mobile_privacy_logs.dart',
    'privacy_log_validator.dart',
  };

  static const bannedLogLinePatterns = [
    'audioPath=',
    'audio_path=',
    'entry_id=',
    'entryId=',
    'path=\$path',
    'privacyHash(',
    'hash=\${',
    'exception=\${details.exceptionAsString',
    'failure.message',
    'transcript=',
    'Bearer sk-',
    '@example.com',
  ];

  /// Scan in-memory source (used by unit tests and production graph walk).
  static List<String> scanSource({
    required String path,
    required List<String> lines,
    String marker = fixtureMarker,
  }) {
    final failures = <String>[];
    var inFixture = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed == '// $marker' || trimmed == marker) {
        inFixture = !inFixture;
        continue;
      }
      if (inFixture) continue;

      if (trimmed.startsWith('//')) continue;

      if (_isLoggingLine(line)) {
        for (final pattern in bannedLogLinePatterns) {
          if (line.contains(pattern)) {
            failures.add('$path:${i + 1}: banned log fragment "$pattern"');
          }
        }
      }
    }
    return failures;
  }

  static List<String> validateProductionGraph(String root) {
    final failures = <String>[];

    for (final scanRoot in scanRoots) {
      final dir = Directory('$root/$scanRoot');
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path;
        if (path.contains('/test/')) continue;
        if (approvedLogWrappers.any(path.endsWith)) continue;
        failures.addAll(
          scanSource(path: path, lines: entity.readAsLinesSync()),
        );
      }
    }

    _checkPipelineWrappers(root, failures);
    _checkPrivateLog(root, failures);
    _checkCrashDiagnostics(root, failures);
    _checkAuthSyncBillingLogging(root, failures);

    return failures;
  }

  static bool _isLoggingLine(String line) {
    return RegExp(r'\bdebugPrint\s*\(').hasMatch(line) ||
        RegExp(r'(?<![.\w])print\s*\(').hasMatch(line) ||
        RegExp(r'\bdeveloper\.log\s*\(').hasMatch(line) ||
        line.contains('ReleaseLogger.debugDetail');
  }

  static void _checkPipelineWrappers(String root, List<String> failures) {
    final recordLog = File('$root/lib/services/record_pipeline_log.dart');
    if (!recordLog.existsSync()) {
      failures.add('record_pipeline_log.dart missing');
      return;
    }
    final text = recordLog.readAsStringSync();
    if (!text.contains('ReleaseLogger.emit')) {
      failures.add('record_pipeline_log.dart must route through ReleaseLogger');
    }
    if (RegExp(r"log\('audio file path=").hasMatch(text)) {
      failures.add('record_pipeline_log.dart logs raw audio paths in release');
    }

    final transcriptionLog = File(
      '$root/lib/features/voice_capture/transcription/transcription_log.dart',
    );
    if (!transcriptionLog.readAsStringSync().contains('ReleaseLogger')) {
      failures.add('transcription_log.dart must route through ReleaseLogger');
    }
  }

  static void _checkPrivateLog(String root, List<String> failures) {
    final privateLog = File('$root/lib/security/private_log.dart');
    if (!privateLog.existsSync()) return;
    final text = privateLog.readAsStringSync();
    if (text.contains('privacyHash')) {
      failures.add('private_log.dart must not log content hashes');
    }
  }

  static void _checkCrashDiagnostics(String root, List<String> failures) {
    final crash = File('$root/lib/startup/archive_me_crash_diagnostics.dart');
    if (!crash.existsSync()) return;
    final text = crash.readAsStringSync();
    if (text.contains('ReleaseLogger.logFailure') &&
        text.contains('if (kDebugMode)')) {
      return;
    }
    failures.add(
      'archive_me_crash_diagnostics.dart must use ReleaseLogger with debug-only detail',
    );
  }

  static void _checkAuthSyncBillingLogging(String root, List<String> failures) {
    for (final relative in [
      'lib/features/auth/application/auth_session_notifier.dart',
      'lib/features/sync/application/sync_notifier.dart',
      'lib/features/billing/application/billing_notifier.dart',
    ]) {
      final file = File('$root/$relative');
      if (!file.existsSync()) continue;
      final text = file.readAsStringSync();
      if (text.contains('failure.message')) {
        failures.add('$relative logs raw ApiFailure.message');
      }
      if (!text.contains('ReleaseLogger.apiFailure') &&
          !text.contains('ReleaseLogger.exceptionFailure')) {
        failures.add('$relative must log failures via ReleaseLogger');
      }
    }
  }
}
