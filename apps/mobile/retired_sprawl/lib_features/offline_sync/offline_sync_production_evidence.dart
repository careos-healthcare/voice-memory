import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class OfflineSyncProductionEvidence {
  static const String sourceCommitSha = String.fromEnvironment(
    'SOURCE_COMMIT_SHA',
    defaultValue: '',
  );

  static Future<String> toJson({
    required bool success,
    required int reflectionsRecordedOffline,
    required int reflectionsSynced,
    required bool beliefPreserved,
    required bool evidencePreserved,
    required bool physicalDevice,
  }) async {
    var device = '';
    if (Platform.isIOS) {
      final ios = await DeviceInfoPlugin().iosInfo;
      device = ios.utsname.machine;
      if (!ios.isPhysicalDevice) {
        device = '$device (simulator — invalid)';
      }
    } else if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      device = android.model;
      if (!android.isPhysicalDevice) {
        device = '$device (emulator — invalid)';
      }
    }

    final passing =
        physicalDevice &&
        success &&
        beliefPreserved &&
        evidencePreserved &&
        reflectionsRecordedOffline > 0 &&
        reflectionsRecordedOffline == reflectionsSynced;

    final packageInfo = await PackageInfo.fromPlatform();

    final payload = {
      'success': passing,
      'device': device,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'reflections_recorded_offline': reflectionsRecordedOffline,
      'reflections_synced': reflectionsSynced,
      'belief_preserved': beliefPreserved,
      'evidence_preserved': evidencePreserved,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'marketing_version': packageInfo.version,
      'build_number': int.tryParse(packageInfo.buildNumber) ?? packageInfo.buildNumber,
      if (sourceCommitSha.isNotEmpty) 'commit_sha': sourceCommitSha,
      if (!physicalDevice)
        'note': 'Physical device required — emulator/simulator does not count',
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Future<bool> isPhysicalDevice() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) {
      return (await plugin.iosInfo).isPhysicalDevice;
    }
    if (Platform.isAndroid) {
      return (await plugin.androidInfo).isPhysicalDevice;
    }
    return false;
  }
}