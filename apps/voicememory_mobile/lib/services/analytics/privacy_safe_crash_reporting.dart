import 'package:flutter/foundation.dart';

typedef PrivacySafeCrashProvider =
    Future<void> Function(Map<String, String> report);

enum CrashReportingStatus { disabled, enabled }

enum CrashPlatform { android, ios }

enum CrashReleaseChannel { debug, profile, release }

enum SafeCrashCategory {
  startup,
  capture,
  transcription,
  interpretation,
  persistence,
  sync,
  recovery,
  commerce,
  deletion,
  export,
  unknown,
}

enum CrashTimingBand {
  under200ms,
  under500ms,
  under1s,
  under2s,
  under5s,
  over5s,
}

/// Privacy-reviewed release metadata. No installation, account, archive,
/// device, file, or provider identifier is accepted.
final class CrashReportingMetadata {
  CrashReportingMetadata({
    required this.app,
    required this.build,
    required this.platform,
    required this.channel,
  }) {
    _validateReleaseValue(app, 'app');
    _validateReleaseValue(build, 'build');
  }

  final String app;
  final String build;
  final CrashPlatform platform;
  final CrashReleaseChannel channel;
}

/// Fail-closed crash-reporting boundary.
///
/// There is intentionally no API accepting an exception, stack, message,
/// breadcrumb, id, or arbitrary context. Without an installed provider,
/// [status] remains [CrashReportingStatus.disabled] in every build mode.
abstract final class PrivacySafeCrashReporting {
  static PrivacySafeCrashProvider? _provider;
  static CrashReportingMetadata? _metadata;

  static CrashReportingStatus get status =>
      _provider == null || _metadata == null
      ? CrashReportingStatus.disabled
      : CrashReportingStatus.enabled;

  static void configure({
    required CrashReportingMetadata metadata,
    PrivacySafeCrashProvider? provider,
  }) {
    _metadata = metadata;
    _provider = provider;
  }

  static Future<void> report({
    required SafeCrashCategory category,
    required CrashTimingBand timing,
  }) async {
    final provider = _provider;
    final metadata = _metadata;
    if (provider == null || metadata == null) return;

    final payload = _payload(metadata, category, timing);
    // Reconstruct and validate at the last boundary so future buffering or
    // enrichment cannot bypass the privacy-reviewed schema.
    final checked = _validateProviderPayload(payload);
    if (checked == null) return;
    try {
      await provider(checked);
    } catch (_) {
      // Provider details are deliberately not printed or forwarded.
    }
  }

  static Map<String, String> _payload(
    CrashReportingMetadata metadata,
    SafeCrashCategory category,
    CrashTimingBand timing,
  ) => Map.unmodifiable({
    'app': metadata.app,
    'build': metadata.build,
    'platform': switch (metadata.platform) {
      CrashPlatform.android => 'android',
      CrashPlatform.ios => 'ios',
    },
    'channel': switch (metadata.channel) {
      CrashReleaseChannel.debug => 'debug',
      CrashReleaseChannel.profile => 'profile',
      CrashReleaseChannel.release => 'release',
    },
    'category': switch (category) {
      SafeCrashCategory.startup => 'startup',
      SafeCrashCategory.capture => 'capture',
      SafeCrashCategory.transcription => 'transcription',
      SafeCrashCategory.interpretation => 'interpretation',
      SafeCrashCategory.persistence => 'persistence',
      SafeCrashCategory.sync => 'sync',
      SafeCrashCategory.recovery => 'recovery',
      SafeCrashCategory.commerce => 'commerce',
      SafeCrashCategory.deletion => 'deletion',
      SafeCrashCategory.export => 'export',
      SafeCrashCategory.unknown => 'unknown',
    },
    'timing': switch (timing) {
      CrashTimingBand.under200ms => 'under_200ms',
      CrashTimingBand.under500ms => 'under_500ms',
      CrashTimingBand.under1s => 'under_1s',
      CrashTimingBand.under2s => 'under_2s',
      CrashTimingBand.under5s => 'under_5s',
      CrashTimingBand.over5s => 'over_5s',
    },
  });

  static Map<String, String>? _validateProviderPayload(
    Map<String, String> payload,
  ) {
    if (!setEquals(payload.keys.toSet(), const {
      'app',
      'build',
      'platform',
      'channel',
      'category',
      'timing',
    })) {
      return null;
    }
    try {
      _validateReleaseValue(payload['app']!, 'app');
      _validateReleaseValue(payload['build']!, 'build');
    } on ArgumentError {
      return null;
    }
    if (!const {'android', 'ios'}.contains(payload['platform']) ||
        !const {'debug', 'profile', 'release'}.contains(payload['channel']) ||
        !const {
          'startup',
          'capture',
          'transcription',
          'interpretation',
          'persistence',
          'sync',
          'recovery',
          'commerce',
          'deletion',
          'export',
          'unknown',
        }.contains(payload['category']) ||
        !const {
          'under_200ms',
          'under_500ms',
          'under_1s',
          'under_2s',
          'under_5s',
          'over_5s',
        }.contains(payload['timing'])) {
      return null;
    }
    return Map.unmodifiable(payload);
  }

  @visibleForTesting
  static void resetForTest() {
    _provider = null;
    _metadata = null;
  }
}

final RegExp _releaseValue = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,31}$');
final RegExp _sensitiveReleaseValue = RegExp(
  r'(token|secret|password|exception|error|transcript|prompt|question|'
  r'correction|recovery_code|sync_key|path|filename)',
  caseSensitive: false,
);

void _validateReleaseValue(String value, String field) {
  if (!_releaseValue.hasMatch(value) ||
      _sensitiveReleaseValue.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'unsafe release metadata');
  }
}
