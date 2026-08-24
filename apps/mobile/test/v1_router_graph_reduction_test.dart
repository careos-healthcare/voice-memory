import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/router/v1_quarantine_redirects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 production router has no quarantined screen imports', () {
    expect(V1FeatureFlags.enableV1Only, isTrue);
    final router = File('lib/router/app_router.dart').readAsStringSync();
    for (final banned in [
      'CapacityLoopScreen',
      'BetaFeedbackScreen',
      'JournalScreen',
      'PatternMapScreen',
      'DeveloperDiagnosticsScreen',
      'WeeklyArchiveReviewScreen',
    ]) {
      expect(router, isNot(contains(banned)), reason: 'still imports $banned');
    }
    expect(router, contains('V1QuarantineRedirects.routes'));
  });

  test('quarantine redirect list covers lab routes', () {
    expect(V1QuarantineRedirects.exactPaths, contains('/capacity-loop'));
    expect(V1QuarantineRedirects.exactPaths, contains('/beta-feedback'));
    expect(V1QuarantineRedirects.exactPaths, contains('/journal'));
    expect(V1QuarantineRedirects.exactPaths, contains('/subscription'));
    expect(V1QuarantineRedirects.exactPaths, contains('/pricing'));
    expect(V1QuarantineRedirects.exactPaths, contains('/restore-purchases'));
    expect(
      V1QuarantineRedirects.parameterizedPaths,
      contains('/archive-packs/:id'),
    );
  });
}