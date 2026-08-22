import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_launch_product_contract.dart';
import 'package:archiveme_mobile/core/config/v1_production_allowlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('launch contract defines capabilities aligned with allowlist', () {
    expect(V1LaunchProductContract.launchCapabilities.length, 10);
    for (final cap in V1LaunchProductContract.launchCapabilities) {
      expect(cap.id, isNotEmpty);
      expect(cap.routes, isNotEmpty);
    }
    expect(V1ProductionAllowlist.launchCapabilities, contains('voice_capture'));
    expect(
      V1ProductionAllowlist.launchCapabilities,
      contains('free_beta_unlimited_local_archive'),
    );
    expect(
      V1ProductionAllowlist.launchCapabilities,
      isNot(contains('optional_paid_deeper_history')),
    );
  });

  test('production screens do not reference quarantined widgets', () {
    final checks = <(String file, String symbol)>[
      ('lib/screens/account_screen.dart', 'WeeklyGrowthPreviewCard'),
      ('lib/screens/account_screen.dart', 'AiAccuracyFeedbackStore'),
      ('lib/screens/account_screen.dart', 'BetaFeedbackSheet'),
      ('lib/screens/account_screen.dart', 'ProUtilityExpansionSection'),
      ('lib/screens/entry_detail_screen.dart', 'RememberThisButton'),
      ('lib/screens/entry_detail_screen.dart', 'SaveAsFactButton'),
      ('lib/screens/entry_detail_screen.dart', 'PinEntryButton'),
      ('lib/screens/paywall_screen.dart', 'BetaFeedbackCaptureCard'),
      ('lib/screens/paywall_screen.dart', 'BetaFeedbackCaptureStore'),
      ('lib/router/app_router.dart', 'CuriosityNotificationLaunchController'),
      ('lib/router/app_router.dart', 'ObjectiveWidgetPendingRouteStore'),
    ];

    final violations = <String>[];
    for (final (file, symbol) in checks) {
      final content = File(file).readAsStringSync();
      if (content.contains(symbol)) {
        violations.add('$file still references quarantined $symbol');
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
    final bootstrap = File(
      'lib/startup/archive_me_startup.dart',
    ).readAsStringSync();
    expect(bootstrap, isNot(contains(r'$_startupError')));
    expect(bootstrap, contains('ConsumerUiCopy.startupLocalStorageFailedBody'));
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