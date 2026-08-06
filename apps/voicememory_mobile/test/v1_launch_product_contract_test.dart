import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/config/v1_launch_product_contract.dart';
import 'package:voicememory_mobile/core/config/v1_production_allowlist.dart';

void main() {
  test('launch contract defines nine capabilities aligned with allowlist', () {
    expect(V1LaunchProductContract.launchCapabilities.length, 10);
    for (final cap in V1LaunchProductContract.launchCapabilities) {
      expect(cap.id, isNotEmpty);
      expect(cap.routes, isNotEmpty);
    }
    expect(
      V1ProductionAllowlist.launchCapabilities,
      contains('voice_capture'),
    );
    expect(
      V1ProductionAllowlist.launchCapabilities,
      contains('optional_paid_deeper_history'),
    );
  });

  test('production screens do not embed quarantined widgets when V1-only', () {
    final checks = <(String file, String widget)>[
      ('lib/screens/account_screen.dart', 'WeeklyGrowthPreviewCard'),
      ('lib/screens/account_screen.dart', 'AiAccuracyFeedbackStore'),
      ('lib/screens/account_screen.dart', 'BetaFeedbackSheet'),
      ('lib/screens/entry_detail_screen.dart', 'RememberThisButton'),
      ('lib/screens/paywall_screen.dart', 'BetaFeedbackCaptureCard'),
    ];

    final violations = <String>[];
    for (final (file, widget) in checks) {
      final content = File(file).readAsStringSync();
      if (content.contains(widget) &&
          !content.contains('V1FeatureFlags.enableV1Only')) {
        violations.add('$file renders $widget without V1 gate');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('paywall copy does not promise quarantined Pro features', () {
    final paywallCopy = File(
      'lib/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart',
    ).readAsStringSync();
    for (final banned in [
      'Weekly archive reviews',
      'Timeline views over time',
    ]) {
      expect(paywallCopy, isNot(contains(banned)));
    }
  });

  test('startup never shows raw exceptions to users', () {
    final bootstrap = File('lib/startup/archive_me_startup.dart').readAsStringSync();
    expect(bootstrap, isNot(contains(r'$_startupError')));
    expect(
      bootstrap,
      contains('ConsumerUiCopy.startupLocalStorageFailedBody'),
    );
  });

  test('blocked routes stay out of production router builders', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    for (final blocked in V1ProductionAllowlist.blockedProductionScreens) {
      expect(
        router.contains('builder: (context, state) => const $blocked(') ||
            router.contains('builder: (context, state) => $blocked('),
        isFalse,
        reason: '$blocked must not be a production route builder',
      );
    }
  });

  test('trust phrases documented in product contract', () {
    expect(V1LaunchProductContract.trustPhrases, isNotEmpty);
    expect(
      V1LaunchProductContract.canonicalPromise,
      contains('private voice archive'),
    );
  });
}
