import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/config/v1_capability_registry.dart';

void main() {
  test('focused V1 capability registry has a minimal allowlist', () {
    expect(V1CapabilityRegistry.androidPermissionAllowlist, {
      'android.permission.INTERNET',
      'android.permission.RECORD_AUDIO',
      'android.permission.USE_BIOMETRIC',
      'com.android.vending.BILLING',
    });
    expect(V1CapabilityRegistry.iosUsageDescriptionAllowlist, {
      'NSMicrophoneUsageDescription',
      'NSFaceIDUsageDescription',
    });
    expect(V1CapabilityRegistry.notifications, isFalse);
    expect(V1CapabilityRegistry.backgroundProcessing, isFalse);
    expect(V1CapabilityRegistry.health, isFalse);
    expect(V1CapabilityRegistry.bluetooth, isFalse);
    expect(V1CapabilityRegistry.localNetwork, isFalse);
    expect(V1CapabilityRegistry.nearbyWifi, isFalse);
    expect(V1CapabilityRegistry.location, isFalse);
    expect(V1CapabilityRegistry.calendar, isFalse);
    expect(V1CapabilityRegistry.cameraAndPhotos, isFalse);
    expect(V1CapabilityRegistry.activityRecognition, isFalse);
    expect(V1CapabilityRegistry.speechRecognition, isFalse);
    expect(V1CapabilityRegistry.p2pAndWebRtc, isFalse);
  });

  test('V1 ambient location and calendar collector is physically absent', () {
    expect(
      File('lib/services/ambient_metadata_collector.dart').existsSync(),
      isFalse,
    );
  });

  test('excluded startup services are compile-time gated', () {
    final source = File('lib/services/app_services.dart').readAsStringSync();
    final startup = File(
      'lib/startup/archive_me_startup.dart',
    ).readAsStringSync();
    final recordingComposition = File(
      'lib/services/composition/recording_services.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('V1CapabilityRegistry.')));
    expect(
      recordingComposition,
      contains('const ForegroundOnlyTranscriptionScheduler()'),
    );
    expect(startup, isNot(contains('V1CapabilityRegistry.notifications')));
    expect(startup, isNot(contains('V1CapabilityRegistry.nativeExtensions')));
    expect(startup, isNot(contains('V1CapabilityRegistry.liveVoice')));
  });

  test('iOS Release points at minimal plist and entitlements', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final info = File('ios/Runner/Info-Release.plist').readAsStringSync();
    final entitlements = File(
      'ios/Runner/Runner-Release.entitlements',
    ).readAsStringSync();
    final scheme = File(
      'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
    ).readAsStringSync();

    expect(project, contains('INFOPLIST_FILE = "Runner/Info-Release.plist";'));
    expect(
      project,
      contains(
        'CODE_SIGN_ENTITLEMENTS = "Runner/Runner-Release.entitlements";',
      ),
    );
    expect(info, contains('<key>NSMicrophoneUsageDescription</key>'));
    expect(info, contains('<key>NSFaceIDUsageDescription</key>'));
    for (final forbidden in [
      'NSHealth',
      'NSBluetooth',
      'NSBonjourServices',
      'NSLocalNetworkUsageDescription',
      'NSLocation',
      'NSCalendars',
      'NSCamera',
      'NSPhoto',
      'NSSpeechRecognition',
      'UIBackgroundModes',
      'BGTaskSchedulerPermittedIdentifiers',
    ]) {
      expect(info, isNot(contains(forbidden)));
    }
    expect(entitlements, contains('<dict/>'));
    expect(entitlements, isNot(contains('com.apple.developer.')));
    expect(entitlements, isNot(contains('keychain-access-groups')));
    expect(project, isNot(contains('Embed App Extensions')));
    expect(scheme, isNot(contains('ShareExtension')));
    expect(scheme, isNot(contains('ArchiveMeWidgets')));
  });
}
