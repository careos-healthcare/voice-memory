import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/record/recording_duration_policy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

void main() {
  test('recording safety cap is identical for every entitlement state', () {
    expect(RecordingDurationPolicy.maxSeconds, 300);
    expect(RecordingDurationPolicy.shouldAutoStop(299), isFalse);
    expect(RecordingDurationPolicy.shouldAutoStop(300), isTrue);
    expect(RecordingDurationPolicy.shouldAutoStop(301), isTrue);
  });

  test('cap processing uses the canonical recording guidance', () {
    expect(
      RecordingDurationPolicy.processingLabel,
      ConsumerUiCopy.recordSubtitle,
    );
  });

  test(
    'record controller has a safety cap without an original-content paywall',
    () {
      final source = File(
        'lib/features/recording/domain/application/'
        'capture_session_coordinator.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('_showRecordingLimitPaywall')));
      expect(
        source,
        isNot(contains('ValueMomentPaywallReason.recordingLimit')),
      );
      expect(source, contains('RecordingDurationPolicy.maxSeconds'));
      expect(source, contains('RecordingDurationPolicy.shouldAutoStop('));
      expect(source, contains('maxDurationSeconds: maximumSeconds'));
    },
  );
}
