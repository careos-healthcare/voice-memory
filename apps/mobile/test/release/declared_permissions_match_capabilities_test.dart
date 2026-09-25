import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Declaration → [V1CapabilityRegistry] flag. A listed declaration may appear
/// in Info.plist, Runner.entitlements, or the source AndroidManifest only when
/// its flag is true. `tools:node="remove"` entries are strips, not requests.
const _declarationFlags = <String, bool>{
  'NSMicrophoneUsageDescription': V1CapabilityRegistry.microphone,
  'NSFaceIDUsageDescription': V1CapabilityRegistry.biometricLock,
  'NSSpeechRecognitionUsageDescription': V1CapabilityRegistry.speechRecognition,
  'NSHealthShareUsageDescription': V1CapabilityRegistry.health,
  'NSHealthUpdateUsageDescription': false,
  'NSCalendarsFullAccessUsageDescription': V1CapabilityRegistry.calendar,
  'NSCalendarsUsageDescription': V1CapabilityRegistry.calendar,
  'NSLocationWhenInUseUsageDescription': V1CapabilityRegistry.location,
  // Always location is forbidden. Only When In Use may be declared.
  'NSLocationAlwaysAndWhenInUseUsageDescription': false,
  'NSLocationAlwaysUsageDescription': false,
  'NSBluetoothAlwaysUsageDescription': V1CapabilityRegistry.bluetooth,
  'NSBluetoothPeripheralUsageDescription': V1CapabilityRegistry.bluetooth,
  'NSLocalNetworkUsageDescription': V1CapabilityRegistry.localNetwork,
  'NSCameraUsageDescription': V1CapabilityRegistry.cameraAndPhotos,
  'NSPhotoLibraryUsageDescription': V1CapabilityRegistry.cameraAndPhotos,
  'NSPhotoLibraryAddUsageDescription': V1CapabilityRegistry.cameraAndPhotos,
  'NSMotionUsageDescription': V1CapabilityRegistry.activityRecognition,
  'com.apple.developer.healthkit': V1CapabilityRegistry.health,
  'aps-environment': V1CapabilityRegistry.notifications,
  'android.permission.RECORD_AUDIO': V1CapabilityRegistry.microphone,
  'android.permission.USE_BIOMETRIC': V1CapabilityRegistry.biometricLock,
  'android.permission.INTERNET': V1CapabilityRegistry.internet,
  'android.permission.ACCESS_NETWORK_STATE': V1CapabilityRegistry.internet,
  'android.permission.ACCESS_FINE_LOCATION': V1CapabilityRegistry.location,
  'android.permission.ACCESS_COARSE_LOCATION': V1CapabilityRegistry.location,
  'android.permission.ACCESS_BACKGROUND_LOCATION': V1CapabilityRegistry.location,
  'android.permission.BLUETOOTH': V1CapabilityRegistry.bluetooth,
  'android.permission.BLUETOOTH_ADMIN': V1CapabilityRegistry.bluetooth,
  'android.permission.BLUETOOTH_SCAN': V1CapabilityRegistry.bluetooth,
  'android.permission.BLUETOOTH_CONNECT': V1CapabilityRegistry.bluetooth,
  'android.permission.BLUETOOTH_ADVERTISE': V1CapabilityRegistry.bluetooth,
  'android.permission.NEARBY_WIFI_DEVICES': V1CapabilityRegistry.nearbyWifi,
  'android.permission.READ_CALENDAR': V1CapabilityRegistry.calendar,
  'android.permission.WRITE_CALENDAR': V1CapabilityRegistry.calendar,
  'android.permission.health.READ_STEPS': V1CapabilityRegistry.health,
  'android.permission.ACTIVITY_RECOGNITION':
      V1CapabilityRegistry.activityRecognition,
  'android.permission.READ_MEDIA_AUDIO': false,
  'android.permission.FOREGROUND_SERVICE_DATA_SYNC':
      V1CapabilityRegistry.backgroundProcessing,
  'android.permission.RECEIVE_BOOT_COMPLETED':
      V1CapabilityRegistry.backgroundProcessing ||
      V1CapabilityRegistry.gentleReminders ||
      V1CapabilityRegistry.notifications,
  'android.permission.POST_NOTIFICATIONS': V1CapabilityRegistry.notifications,
  'android.permission.SCHEDULE_EXACT_ALARM': V1CapabilityRegistry.notifications,
  'com.android.vending.BILLING': V1CapabilityRegistry.storeBilling,
};

void main() {
  test('declared permissions match V1 capability flags', () {
    final root = Directory.current.path.endsWith('apps/mobile')
        ? Directory.current
        : Directory('apps/mobile');
    final plist = File('${root.path}/ios/Runner/Info.plist').readAsStringSync();
    final entitlements = File(
      '${root.path}/ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final manifest = File(
      '${root.path}/android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    final declared = <String>{
      ..._plistKeys(plist),
      ..._plistKeys(entitlements),
      ..._requestedAndroidPermissions(manifest),
    };

    final violations = [
      for (final name in declared)
        if (_declarationFlags[name] == false) name,
    ]..sort();

    expect(
      violations,
      isEmpty,
      reason:
          'Declared while the matching V1CapabilityRegistry flag is false: '
          '${violations.join(', ')}',
    );
  });
}

Set<String> _plistKeys(String plist) {
  return RegExp(r'<key>([^<]+)</key>').allMatches(plist).map((match) {
    return match.group(1)!;
  }).toSet();
}

/// Positive `<uses-permission>` names. `tools:node="remove"` strips a merge.
Set<String> _requestedAndroidPermissions(String manifest) {
  final tags = RegExp(
    r'<uses-permission\b[^>]*/>',
    dotAll: true,
  ).allMatches(manifest);
  final names = <String>{};
  for (final tag in tags) {
    final text = tag.group(0)!;
    if (text.contains('tools:node="remove"')) continue;
    final name = RegExp(r'android:name="([^"]+)"').firstMatch(text);
    if (name != null) names.add(name.group(1)!);
  }
  return names;
}
