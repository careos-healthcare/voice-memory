import 'dart:io';

import 'package:archiveme_mobile/features/onboarding/remote_processing_consent_decision.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_step.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/repo_file_scan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MobilePrefsStore prefs;
  late RemoteProcessingConsentStore consentStore;
  late RemoteProcessingConsentGate gate;
  late OnDeviceProcessingStoreForTest storeForTest;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vm_onboarding_consent_');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    consentStore = RemoteProcessingConsentStore(prefs);
    gate = RemoteProcessingConsentGate(consentStore);
    storeForTest = OnDeviceProcessingStoreForTest(prefs);
    await OnDeviceProcessingStore.resetForTest();
    OnDeviceProcessingStore.debugPlatformOverride = 'ios';
  });

  tearDown(() async {
    await OnDeviceProcessingStore.resetForTest();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('the consent step says what it changes before the customer acts', () {
    testWidgets('the setting-change copy sits above both buttons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteProcessingConsentStep(onDecision: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final change = find.byKey(
        const Key('remote_processing_consent_setting_change'),
      );
      final scope = find.byKey(
        const Key('remote_processing_consent_setting_scope'),
      );
      final allow = find.byKey(const Key('remote_processing_consent_allow'));
      final decline = find.byKey(
        const Key('remote_processing_consent_decline'),
      );

      expect(change, findsOneWidget);
      expect(scope, findsOneWidget);
      expect(allow, findsOneWidget);
      expect(decline, findsOneWidget);

      // Before, not after, and in the same scroll column as the buttons.
      for (final explanation in [change, scope]) {
        expect(
          tester.getTopLeft(explanation).dy,
          lessThan(tester.getTopLeft(allow).dy),
        );
        expect(
          tester.getTopLeft(explanation).dy,
          lessThan(tester.getTopLeft(decline).dy),
        );
      }
    });

    test('the copy names the switch, the condition, and no absolutes', () {
      const change = RemoteProcessingConsentCopy.settingChangeBody;
      const scope = RemoteProcessingConsentCopy.settingChangeScope;

      expect(change, contains('on-device-only switch'));
      expect(change, contains('Settings'));
      expect(
        change,
        contains(RemoteProcessingConsentCopy.allowCta),
        reason: 'the copy has to name the button it describes',
      );
      expect(
        change.toLowerCase(),
        contains('remote processing stays off'),
        reason: 'states that the switch still vetoes remote work',
      );
      expect(scope, contains('transcription and reflection'));

      for (final absolute in [
        '100%',
        'zero',
        'entirely',
        'always',
        'never',
        'only ever',
      ]) {
        expect(change.toLowerCase(), isNot(contains(absolute)));
        expect(scope.toLowerCase(), isNot(contains(absolute)));
      }
    });
  });

  group('granting in onboarding takes effect', () {
    test('granting clears the on-device-only toggle', () async {
      expect(
        OnDeviceProcessingStore.enabled,
        isTrue,
        reason: 'precondition: unset on iOS resolves to on-device-only',
      );

      await OnboardingRemoteProcessingDecision.record(
        allow: true,
        consentStore: consentStore,
      );

      expect(OnDeviceProcessingStore.enabled, isFalse);
      expect(OnDeviceProcessingStore.hasExplicitPreference, isTrue);
      for (final purpose in RemoteProcessingPurpose.values) {
        expect(
          await gate.isPurposePermittedNow(purpose),
          isTrue,
          reason: '$purpose was granted in the flow',
        );
      }
    });

    test('declining leaves the toggle alone and permits nothing', () async {
      await OnboardingRemoteProcessingDecision.record(
        allow: false,
        consentStore: consentStore,
      );

      expect(OnDeviceProcessingStore.enabled, isTrue);
      expect(
        OnDeviceProcessingStore.hasExplicitPreference,
        isFalse,
        reason: 'declining must not write a choice the customer did not make',
      );
      for (final purpose in RemoteProcessingPurpose.values) {
        expect(await gate.isPurposePermittedNow(purpose), isFalse);
      }
    });

    test('granting on Android leaves the already-off toggle permitted',
        () async {
      await OnDeviceProcessingStore.resetForTest();
      OnDeviceProcessingStore.debugPlatformOverride = 'android';
      expect(OnDeviceProcessingStore.enabled, isFalse);

      await OnboardingRemoteProcessingDecision.record(
        allow: true,
        consentStore: consentStore,
      );

      expect(OnDeviceProcessingStore.enabled, isFalse);
      expect(
        await gate.isPurposePermittedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isTrue,
      );
    });

    test('clearing the toggle cannot permit an ungranted purpose', () async {
      await consentStore.grant(
        purposes: {RemoteProcessingPurpose.remoteTranscription},
      );
      await OnDeviceProcessingStore.setEnabled(false);

      expect(
        await gate.isPurposePermittedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isTrue,
      );
      expect(
        await gate.isPurposePermittedNow(
          RemoteProcessingPurpose.remoteReflection,
        ),
        isFalse,
        reason: 'the cleared toggle is necessary, not sufficient',
      );
    });
  });

  group('existing installs are not migrated', () {
    test('a stored on-device-only choice survives prior remote consent',
        () async {
      // The install this change must not touch: consent granted under the old
      // behaviour, on-device-only explicitly on, and no in-flow grant since.
      await consentStore.grant(
        purposes: RemoteProcessingPurposeStorage.onboardingGrant,
      );
      await storeForTest.setEnabled(true);

      expect(await storeForTest.readExplicit(), isTrue);
      await OnDeviceProcessingStore.resetForTest();
      OnDeviceProcessingStore.debugPlatformOverride = 'ios';

      // Nothing on this path runs a migration, so the stored value is still
      // the stored value and the gate still vetoes.
      expect(await storeForTest.readExplicit(), isTrue);
      expect(
        await storeForTest.readEnabled(),
        isTrue,
        reason: 'no migration may flip a privacy setting behind the customer',
      );

      await OnDeviceProcessingStore.setEnabled(
        await storeForTest.readEnabled(),
      );
      for (final purpose in RemoteProcessingPurpose.values) {
        final decision = await gate.evaluateFor(purpose);
        expect(decision.permitted, isFalse);
        expect(decision.currentPermission, isTrue);
      }
    });

    test('an Android install that chose on-device-only keeps it', () async {
      await storeForTest.setEnabled(true);
      await OnDeviceProcessingStore.resetForTest();
      OnDeviceProcessingStore.debugPlatformOverride = 'android';

      expect(OnDeviceProcessingStore.defaultEnabled, isFalse);
      expect(
        await storeForTest.readEnabled(),
        isTrue,
        reason: 'the new Android default must not overwrite a real choice',
      );
    });

    test('nothing under lib/ clears the toggle outside the known call sites',
        () {
      // A migration would have to clear the toggle from somewhere. Enumerating
      // the callers is how a future one gets noticed in review.
      const allowed = {
        'lib/screens/settings_screen.dart',
        'lib/features/onboarding/remote_processing_consent_decision.dart',
        'lib/features/privacy/on_device_processing_store.dart',
        'lib/features/capture_flow/adapters/pipeline_capture_adapters.dart',
      };

      // `followLinks: false` deliberately: most `lib/features/<name>/` entries
      // are symlinks into `retired_sprawl/lib_features/`, and following them
      // makes the walk cyclic. The retired tree is scanned directly instead, so
      // the shipped code behind those links is still covered.
      final libDir = resolveRepoScanFile('lib/main.dart').parent;
      final retiredDir = Directory(
        '${libDir.parent.path}/retired_sprawl/lib_features',
      );

      final offenders = <String>[];
      for (final root in [libDir, if (retiredDir.existsSync()) retiredDir]) {
        for (final entity in root.listSync(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final relative = entity.path.startsWith(libDir.path)
              ? 'lib${entity.path.substring(libDir.path.length)}'
              : 'lib/features'
                    '${entity.path.substring(retiredDir.path.length)}';
          if (allowed.contains(relative)) continue;
          final source = entity.readAsStringSync();
          if (source.contains('OnDeviceProcessingStore.setEnabled') ||
              source.contains(
                'OnDeviceProcessingStore.clearForGrantedRemoteConsent',
              )) {
            offenders.add(relative);
          }
        }
      }

      expect(offenders, isEmpty);
    });
  });

  group('re-enabling the toggle vetoes everything', () {
    test('after granting in onboarding, turning it back on stops remote',
        () async {
      await OnboardingRemoteProcessingDecision.record(
        allow: true,
        consentStore: consentStore,
      );

      // Control: with the toggle off, both purposes are permitted. Without
      // this, the veto assertion below could pass because consent never landed.
      for (final purpose in RemoteProcessingPurpose.values) {
        expect(await gate.isPurposePermittedNow(purpose), isTrue);
      }

      await OnDeviceProcessingStore.setEnabled(true);

      for (final purpose in RemoteProcessingPurpose.values) {
        final decision = await gate.evaluateFor(purpose);
        expect(decision.permitted, isFalse, reason: '$purpose after re-enable');
        expect(decision.consentAtProcessingTime, isFalse);
        expect(
          decision.currentPermission,
          isTrue,
          reason: 'the veto is the switch, not a withdrawal of consent',
        );
        expect(decision.onDeviceProcessingOnly, isTrue);
      }
      expect(await gate.isPermittedNow(), isFalse);
    });
  });
}
