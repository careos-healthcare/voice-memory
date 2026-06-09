import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../storage/mobile_prefs_store.dart';

/// Physical-device native push verification state v2 (FCM production).
class NativePushPlatformState {
  const NativePushPlatformState({
    this.permissionGranted = false,
    this.notificationReceived = false,
    this.notificationOpened = false,
    this.archiveDestinationVerified = false,
    this.discoverDestinationVerified = false,
    this.recordDestinationVerified = false,
    this.timestamp = '',
  });

  final bool permissionGranted;
  final bool notificationReceived;
  final bool notificationOpened;
  final bool archiveDestinationVerified;
  final bool discoverDestinationVerified;
  final bool recordDestinationVerified;
  final String timestamp;

  Map<String, dynamic> toJson() => {
        'permission_granted': permissionGranted,
        'notification_received': notificationReceived,
        'notification_opened': notificationOpened,
        'archive_destination_verified': archiveDestinationVerified,
        'discover_destination_verified': discoverDestinationVerified,
        'record_destination_verified': recordDestinationVerified,
        'timestamp': timestamp,
      };

  factory NativePushPlatformState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NativePushPlatformState();
    final legacy = json['destinations_verified'];
    final legacyRoutes =
        legacy is List ? legacy.map((e) => e.toString()).toList() : <String>[];
    return NativePushPlatformState(
      permissionGranted: json['permission_granted'] == true,
      notificationReceived: json['notification_received'] == true,
      notificationOpened: json['notification_opened'] == true,
      archiveDestinationVerified: json['archive_destination_verified'] == true ||
          legacyRoutes.contains('/archive-belief'),
      discoverDestinationVerified: json['discover_destination_verified'] == true ||
          legacyRoutes.contains('/discover'),
      recordDestinationVerified: json['record_destination_verified'] == true ||
          legacyRoutes.contains('/record'),
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }
}

class NativePushVerificationStore {
  NativePushVerificationStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'native_push_verification_v2';

  Future<Map<String, dynamic>> readRaw() async {
    return (await _prefs.readMap(_key)) ?? {};
  }

  Future<void> writeRaw(Map<String, dynamic> data) async {
    await _prefs.writeMap(_key, data);
  }

  Future<NativePushPlatformState> platformState(String platform) async {
    final raw = await readRaw();
    final block = raw[platform];
    if (block is! Map) return const NativePushPlatformState();
    return NativePushPlatformState.fromJson(
      Map<String, dynamic>.from(block),
    );
  }

  Future<void> patchPlatform(
    String platform, {
    bool? permissionGranted,
    bool? notificationReceived,
    bool? notificationOpened,
    bool? archiveDestinationVerified,
    bool? discoverDestinationVerified,
    bool? recordDestinationVerified,
    String? timestamp,
  }) async {
    final raw = await readRaw();
    final current = await platformState(platform);
    final next = NativePushPlatformState(
      permissionGranted: permissionGranted ?? current.permissionGranted,
      notificationReceived: notificationReceived ?? current.notificationReceived,
      notificationOpened: notificationOpened ?? current.notificationOpened,
      archiveDestinationVerified:
          archiveDestinationVerified ?? current.archiveDestinationVerified,
      discoverDestinationVerified:
          discoverDestinationVerified ?? current.discoverDestinationVerified,
      recordDestinationVerified:
          recordDestinationVerified ?? current.recordDestinationVerified,
      timestamp: timestamp ?? current.timestamp,
    );
    raw[platform] = next.toJson();
    await writeRaw(raw);
  }

  Future<void> verifyDestination({
    required String platform,
    required String route,
  }) async {
    final current = await platformState(platform);
    final ts = DateTime.now().toUtc().toIso8601String();
    await patchPlatform(
      platform,
      archiveDestinationVerified: current.archiveDestinationVerified ||
          route == '/archive-belief',
      discoverDestinationVerified:
          current.discoverDestinationVerified || route == '/discover',
      recordDestinationVerified:
          current.recordDestinationVerified || route == '/record',
      timestamp: ts,
    );
  }

  Future<String> exportEvidenceJson() async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final local = await platformState(platform);
    final raw = await readRaw();
    final ios = platform == 'ios'
        ? local
        : NativePushPlatformState.fromJson(
            (raw['ios'] as Map?)?.cast<String, dynamic>(),
          );
    final android = platform == 'android'
        ? local
        : NativePushPlatformState.fromJson(
            (raw['android'] as Map?)?.cast<String, dynamic>(),
          );

    await PackageInfo.fromPlatform();
    if (Platform.isIOS) {
      await DeviceInfoPlugin().iosInfo;
    } else {
      await DeviceInfoPlugin().androidInfo;
    }

    final doc = {
      'ios': ios.toJson(),
      'android': android.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }
}
