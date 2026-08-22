import 'package:archiveme_mobile/features/sync_expectation_safety/sync_expectation_safety_copy.dart';

/// Sync expectation safety guard — block unproven cloud/sync copy promises.
abstract final class SyncExpectationSafetyGuard {
  SyncExpectationSafetyGuard._();

  static const allowedPhrases = [
    'on this device',
    'local archive',
    'private on this device',
    'pro keeps the longer proof trail',
    'sync not available yet',
    'backup/export only where true',
  ];

  static const Map<String, SyncExpectationSafetyBlockReason> blockedPhrases = {
    'cloud backup': SyncExpectationSafetyBlockReason.cloudBackup,
    'cross-device sync': SyncExpectationSafetyBlockReason.crossDeviceSync,
    'cross device sync': SyncExpectationSafetyBlockReason.crossDeviceSync,
    'access everywhere': SyncExpectationSafetyBlockReason.accessEverywhere,
    'never lose your archive':
        SyncExpectationSafetyBlockReason.neverLoseArchive,
    'backed up automatically':
        SyncExpectationSafetyBlockReason.backedUpAutomatically,
    'account keeps your trail safe':
        SyncExpectationSafetyBlockReason.accountKeepsTrailSafe,
    'sync across devices': SyncExpectationSafetyBlockReason.syncAcrossDevices,
  };

  static const _honestUnavailableSyncMarkers = [
    'sync not available yet',
    'do not rely on this build as cloud backup',
    'do not claim cloud backup',
    'avoid cloud backup',
    'no cloud backup',
    'not cloud backup',
    'sync is unavailable',
    'sync unavailable',
    'backup/export only where true',
  ];

  static SyncExpectationSafetyGuardResult evaluate(
    String copy, {
    bool syncProven = false,
  }) {
    final lower = copy.toLowerCase().trim();
    if (lower.isEmpty) {
      return const SyncExpectationSafetyGuardResult(
        action: SyncExpectationSafetyAction.allowed,
      );
    }

    if (_isHonestUnavailableSyncCopy(lower)) {
      return const SyncExpectationSafetyGuardResult(
        action: SyncExpectationSafetyAction.allowed,
        usesAllowedLanguage: true,
      );
    }

    if (syncProven) {
      return const SyncExpectationSafetyGuardResult(
        action: SyncExpectationSafetyAction.allowed,
        syncProven: true,
      );
    }

    for (final entry in blockedPhrases.entries) {
      if (lower.contains(entry.key) && !_isNegated(lower, entry.key)) {
        return SyncExpectationSafetyGuardResult(
          action: SyncExpectationSafetyAction.blocked,
          reason: entry.value,
          matchedPhrase: entry.key,
          message: SyncExpectationSafetyCopy.messageFor(entry.value),
        );
      }
    }

    if (_containsAllowedLanguage(lower)) {
      return const SyncExpectationSafetyGuardResult(
        action: SyncExpectationSafetyAction.allowed,
        usesAllowedLanguage: true,
      );
    }

    return const SyncExpectationSafetyGuardResult(
      action: SyncExpectationSafetyAction.allowed,
    );
  }

  static bool passes(String copy, {bool syncProven = false}) =>
      evaluate(copy, syncProven: syncProven).action !=
      SyncExpectationSafetyAction.blocked;

  static bool containsBlockedSyncPromise(
    String copy, {
    bool syncProven = false,
  }) =>
      evaluate(copy, syncProven: syncProven).action ==
      SyncExpectationSafetyAction.blocked;

  static bool containsAllowedLanguage(String copy) =>
      _containsAllowedLanguage(copy.toLowerCase());

  static SyncExpectationSafetyGuardSnapshot snapshot({
    bool syncProven = false,
  }) => SyncExpectationSafetyGuardSnapshot(
    headline: SyncExpectationSafetyCopy.headline,
    body: SyncExpectationSafetyCopy.body,
    allowedLanguageLine: SyncExpectationSafetyCopy.allowedLanguageLine,
    blockedLanguageLine: SyncExpectationSafetyCopy.blockedLanguageLine,
    guardrail: SyncExpectationSafetyCopy.guardrail,
    syncProven: syncProven,
  );

  static bool detectNoBackendImports(String guardSource) {
    const forbiddenImportPrefixes = [
      "import '../api/",
      "import '../../api/",
      'package:firebase/',
      'package:supabase/',
    ];
    const forbiddenModuleNames = [
      'sync_service.dart',
      'cloud_backup_service.dart',
    ];

    for (final prefix in forbiddenImportPrefixes) {
      final pattern = RegExp('^\\s*${RegExp.escape(prefix)}');
      if (guardSource
          .split('\n')
          .any((line) => pattern.hasMatch(line.trim()))) {
        return false;
      }
    }

    return !forbiddenModuleNames.any((name) {
      final pattern = RegExp('^\\s*import .*$name');
      return guardSource
          .split('\n')
          .any((line) => pattern.hasMatch(line.trim()));
    });
  }

  static bool detectCopyGuardOnly(String guardSource) =>
      guardSource.contains('SyncExpectationSafetyCopy.guardrail');

  static bool _containsAllowedLanguage(String lower) {
    for (final phrase in allowedPhrases) {
      if (lower.contains(phrase)) return true;
    }
    return false;
  }

  static bool _isHonestUnavailableSyncCopy(String lower) {
    for (final marker in _honestUnavailableSyncMarkers) {
      if (lower.contains(marker)) return true;
    }
    return false;
  }

  static bool _isNegated(String lower, String phrase) {
    final index = lower.indexOf(phrase);
    if (index < 0) return false;
    final before = lower.substring(0, index);
    if (before.contains('avoid')) return true;
    if (before.contains('do not')) return true;
    if (RegExp(r'\bnot\b').hasMatch(before)) return true;
    if (RegExp(r'\bno\b').hasMatch(before)) return true;
    return false;
  }
}

class SyncExpectationSafetyGuardResult {
  const SyncExpectationSafetyGuardResult({
    required this.action,
    this.reason,
    this.matchedPhrase,
    this.message,
    this.usesAllowedLanguage = false,
    this.syncProven = false,
  });

  final SyncExpectationSafetyAction action;
  final SyncExpectationSafetyBlockReason? reason;
  final String? matchedPhrase;
  final String? message;
  final bool usesAllowedLanguage;
  final bool syncProven;
}

class SyncExpectationSafetyGuardSnapshot {
  const SyncExpectationSafetyGuardSnapshot({
    required this.headline,
    required this.body,
    required this.allowedLanguageLine,
    required this.blockedLanguageLine,
    required this.guardrail,
    required this.syncProven,
  });

  final String headline;
  final String body;
  final String allowedLanguageLine;
  final String blockedLanguageLine;
  final String guardrail;
  final bool syncProven;
}