import 'dart:io';

import 'package:archiveme_mobile/onboarding/onboarding_pages.dart';
import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android targets API 36 and retains only V1 runtime permissions', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, contains('minSdk = maxOf(26, flutter.minSdkVersion)'));
    expect(gradle, contains('verifyProductionReleaseSigning'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules='));
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.USE_BIOMETRIC'));
    expect(manifest, contains('com.android.vending.BILLING'));
    for (final permission in [
      'BLUETOOTH_SCAN',
      'BLUETOOTH_CONNECT',
      'BLUETOOTH_ADVERTISE',
      'NEARBY_WIFI_DEVICES',
      'RECEIVE_BOOT_COMPLETED',
      'FOREGROUND_SERVICE_DATA_SYNC',
      'ACCESS_BACKGROUND_LOCATION',
      'WRITE_CALENDAR',
      'READ_MEDIA_AUDIO',
      'health.READ_STEPS',
    ]) {
      expect(
        manifest,
        contains(
          'android:name="android.permission.$permission" tools:node="remove"',
        ),
      );
    }
    for (final component in [
      'com.bbflight.background_downloader.NotificationReceiver',
      'com.bbflight.background_downloader.OpenFileProvider',
      'com.bbflight.background_downloader.UIDTJobService',
      'com.baseflow.geolocator.GeolocatorLocationService',
      'io.flutter.plugins.imagepicker.ImagePickerFileProvider',
    ]) {
      expect(
        manifest,
        contains('android:name="$component"\n            tools:node="remove"'),
      );
    }
  });

  test('iOS retains microphone purpose text without cut capabilities', () {
    final plist = File('ios/Runner/Info-Release.plist').readAsStringSync();
    final entitlements = File(
      'ios/Runner/Runner-Release.entitlements',
    ).readAsStringSync();

    expect(plist, contains('NSMicrophoneUsageDescription'));
    for (final key in [
      'NSHealthShareUsageDescription',
      'NSBluetoothAlwaysUsageDescription',
      'NSLocalNetworkUsageDescription',
      'NSBonjourServices',
      'UIBackgroundModes',
      'BGTaskSchedulerPermittedIdentifiers',
    ]) {
      expect(plist, isNot(contains(key)));
    }
    expect(entitlements, isNot(contains('com.apple.developer.healthkit')));
  });

  test('V1 starts with welcome before capture and three direct tabs', () {
    final shell = File('lib/widgets/main_shell.dart').readAsStringSync();
    expect(PrimaryDestination.shellValues, hasLength(3));
    expect(shell, contains('NavigationDestination('));
    expect(shell, contains('NavigationRailDestination('));
    expect(shell, isNot(contains('Timer(')));
    expect(shell, isNot(contains('showCanvasFeaturePanel')));
  });

  test('experimental surfaces default off at compile time', () {
    final flag = File(
      'lib/config/experimental_features.dart',
    ).readAsStringSync();
    final graph = File(
      'lib/features/memory_graph/memory_graph_canvas.dart',
    ).readAsStringSync();
    final archive = File(
      'lib/features/archive/screens/archive_belief_screen.dart',
    ).readAsStringSync();
    final capabilities = File(
      'lib/core/config/v1_capability_registry.dart',
    ).readAsStringSync();

    expect(flag, contains("'ENABLE_EXPERIMENTAL'"));
    expect(
      graph,
      contains('if (enableExperimentalFeatures && morningBriefing != null)'),
    );
    expect(archive, contains('ArchiveIntelligencePresentation.build'));
    expect(archive, contains('ArchiveIntelligenceHome'));
    for (final excluded in [
      'notifications = false',
      'health = false',
      'bluetooth = false',
      'location = false',
      'calendar = false',
      'cameraAndPhotos = false',
      'p2pAndWebRtc = false',
    ]) {
      expect(capabilities, contains(excluded));
    }
  });
}