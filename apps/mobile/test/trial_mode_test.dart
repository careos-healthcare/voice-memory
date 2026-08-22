import 'package:archiveme_mobile/features/activation/activation_events_store.dart';
import 'package:archiveme_mobile/features/trial/trial_summary_engine.dart';
import 'package:archiveme_mobile/features/trial/trial_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('frictionVerdict', () {
    test('permissionIssue when mic denied', () {
      final events = ActivationEventCounts.fromMap({'trialMicPermissionDenied': 1});
      expect(frictionVerdict(events), TrialFrictionVerdict.permissionIssue);
    });

    test('recordFriction when opened but never started recording', () {
      final events = ActivationEventCounts.fromMap({'trialAppOpened': 2, 'trialRecordingStarted': 0});
      expect(frictionVerdict(events), TrialFrictionVerdict.recordFriction);
    });

    test('hookIssue when reflection saved but watch-for not accepted', () {
      final events = ActivationEventCounts.fromMap({'firstReflectionSaved': 1, 'watchForPromptAccepted': 0});
      expect(frictionVerdict(events), TrialFrictionVerdict.hookIssue);
    });

    test('clean when reflection saved and watch-for accepted', () {
      final events = ActivationEventCounts.fromMap({'firstReflectionSaved': 1, 'watchForPromptAccepted': 1});
      expect(frictionVerdict(events), TrialFrictionVerdict.clean);
    });

    test('unclear when no signals', () {
      expect(
        frictionVerdict(const ActivationEventCounts()),
        TrialFrictionVerdict.unclear,
      );
    });

    test('permissionIssue takes priority over recordFriction', () {
      final events = ActivationEventCounts.fromMap({'trialAppOpened': 1, 'trialRecordingStarted': 0, 'trialMicPermissionDenied': 1});
      expect(frictionVerdict(events), TrialFrictionVerdict.permissionIssue);
    });
  });
}