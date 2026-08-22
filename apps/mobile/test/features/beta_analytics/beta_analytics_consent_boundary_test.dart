import 'dart:io';

import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_consent_boundary.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_tracker.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MobilePrefsStore prefs;
  final remoteEvents = <String>[];

  setUp(() async {
    remoteEvents.clear();
    BetaAnalyticsTracker.resetForTest();
    prefs = await MobilePrefsStore.open(
      '${Directory.systemTemp.createTempSync('beta_consent_').path}/prefs.json',
    );
    BetaAnalyticsTracker.configure(prefs);
    BetaAnalyticsTracker.captureForTest((event, payload) {
      remoteEvents.add(event);
    });
  });

  test('consent decline records local consent_decision without remote side effects', () async {
    await BetaAnalyticsConsentBoundary.recordOnboardingConsent(granted: false);

    expect(remoteEvents, hasLength(2));
    expect(remoteEvents.every((e) => e == 'consent_decision'), isTrue);

    final payloads = BetaAnalyticsTracker.localLog;
    for (final row in payloads) {
      expect(row.payload['decision'], 'decline');
      expect(
        row.payload['purpose'],
        isIn([
          RemoteProcessingPurpose.remoteTranscription.storageKey,
          RemoteProcessingPurpose.remoteReflection.storageKey,
        ]),
      );
    }
  });

  test('prohibited remote attempt fires monitoring event when not permitted', () async {
    await BetaAnalyticsConsentBoundary.auditRemoteAttempt(
      purpose: RemoteProcessingPurpose.remoteTranscription,
      permitted: false,
    );

    expect(remoteEvents, ['prohibited_remote_attempt_after_decline']);
  });
}
