import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/analytics/privacy_safe_crash_reporting.dart';

void main() {
  setUp(PrivacySafeCrashReporting.resetForTest);

  test('reporting is disabled and fail-closed without a provider', () async {
    PrivacySafeCrashReporting.configure(
      metadata: CrashReportingMetadata(
        app: 'ArchiveMe',
        build: '49',
        platform: CrashPlatform.ios,
        channel: CrashReleaseChannel.release,
      ),
    );

    expect(PrivacySafeCrashReporting.status, CrashReportingStatus.disabled);
    await PrivacySafeCrashReporting.report(
      category: SafeCrashCategory.startup,
      timing: CrashTimingBand.under1s,
    );
  });

  test('provider receives only privacy-reviewed crash fields', () async {
    Map<String, String>? sent;
    PrivacySafeCrashReporting.configure(
      metadata: CrashReportingMetadata(
        app: 'ArchiveMe',
        build: '0.2.0+49',
        platform: CrashPlatform.android,
        channel: CrashReleaseChannel.release,
      ),
      provider: (report) async => sent = report,
    );

    await PrivacySafeCrashReporting.report(
      category: SafeCrashCategory.persistence,
      timing: CrashTimingBand.under2s,
    );

    expect(PrivacySafeCrashReporting.status, CrashReportingStatus.enabled);
    expect(sent, {
      'app': 'ArchiveMe',
      'build': '0.2.0+49',
      'platform': 'android',
      'channel': 'release',
      'category': 'persistence',
      'timing': 'under_2s',
    });
  });

  test('unsafe metadata is rejected at construction', () {
    for (final value in const [
      '../release',
      'person@example.com',
      'raw provider exception',
      'provider_error_500',
      'token_value_that_is_far_too_long_to_be_release_metadata',
    ]) {
      expect(
        () => CrashReportingMetadata(
          app: value,
          build: '49',
          platform: CrashPlatform.ios,
          channel: CrashReleaseChannel.release,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'provider failures are swallowed without accepting raw error data',
    () async {
      PrivacySafeCrashReporting.configure(
        metadata: CrashReportingMetadata(
          app: 'ArchiveMe',
          build: '49',
          platform: CrashPlatform.ios,
          channel: CrashReleaseChannel.release,
        ),
        provider: (_) async => throw StateError('provider detail'),
      );

      await expectLater(
        PrivacySafeCrashReporting.report(
          category: SafeCrashCategory.unknown,
          timing: CrashTimingBand.over5s,
        ),
        completes,
      );
    },
  );
}
