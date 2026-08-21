#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';

/// Static artifact inspection for focused-beta release (Section D).
void main() {
  final root = _findMobileRoot();
  final repoRoot = Directory(root).parent.parent.path;
  final failures = <String>[];

  _checkAndroidManifest(root, failures);
  _checkIosEntitlements(root, failures);
  _checkDisabledCapabilityInit(root, failures);
  _checkVersionIdentity(root, failures);
  _checkLegalLinks(root, failures);
  _checkApiHost(root, failures);

  if (failures.isEmpty) {
    print('inspect_release_artifact: PASS');
    exit(0);
  }

  print('inspect_release_artifact: FAIL (${failures.length} issue(s))');
  for (final failure in failures) {
    print('  - $failure');
  }
  exit(1);
}

String _findMobileRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find pubspec.yaml from ${Directory.current.path}');
    }
    dir = parent;
  }
}

void _checkAndroidManifest(String root, List<String> failures) {
  final manifest = File('$root/android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    failures.add('missing AndroidManifest.xml');
    return;
  }
  final text = manifest.readAsStringSync();
  if (!text.contains('android.permission.INTERNET')) {
    failures.add('Android manifest missing INTERNET permission');
  }
  if (!text.contains('android.permission.RECORD_AUDIO')) {
    failures.add('Android manifest missing RECORD_AUDIO permission');
  }
  if (!V1CapabilityRegistry.storeBilling &&
      text.contains('com.android.vending.BILLING')) {
    failures.add('BILLING permission present while storeBilling=false');
  }
  if (!V1CapabilityRegistry.notifications &&
      text.contains('RECEIVE_BOOT_COMPLETED')) {
    failures.add('RECEIVE_BOOT_COMPLETED present while notifications=false');
  }
}

void _checkIosEntitlements(String root, List<String> failures) {
  final entitlements = File('$root/ios/Runner/Runner.entitlements');
  if (!entitlements.existsSync()) {
    failures.add('missing Runner.entitlements');
    return;
  }
  final text = entitlements.readAsStringSync();
  if (!V1CapabilityRegistry.nativeExtensions &&
      text.contains('group.com.voicememory.mobile')) {
    failures.add('App Group entitlement present while nativeExtensions=false');
  }
  final pbx = File('$root/ios/Runner.xcodeproj/project.pbxproj');
  if (pbx.existsSync()) {
    final pbxText = pbx.readAsStringSync();
    if (!V1CapabilityRegistry.nativeExtensions &&
        pbxText.contains('TodayCheckWidget')) {
      failures.add('TodayCheckWidget target present while nativeExtensions=false');
    }
  }
}

void _checkDisabledCapabilityInit(String root, List<String> failures) {
  final appServices = File('$root/lib/services/app_services.dart');
  if (!appServices.existsSync()) {
    failures.add('missing app_services.dart');
    return;
  }
  final text = appServices.readAsStringSync();
  if (!V1BillingCapability.isEnabled &&
      !text.contains('V1BillingCapability.isEnabled')) {
    failures.add('AppServices missing V1BillingCapability billing gate');
  }
  if (!V1CapabilityRegistry.notifications &&
      text.contains('NativePushService.instance.initialize()') &&
      !text.contains('V1CapabilityRegistry.notifications')) {
    failures.add('Native push may initialize without capability gate');
  }
}

void _checkVersionIdentity(String root, List<String> failures) {
  final pubspec = File('$root/pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true)
      .firstMatch(pubspec);
  if (match == null) {
    failures.add('pubspec.yaml missing version: semver+build');
    return;
  }
  final manifest = File('$root/../../release/focused_beta_status.json');
  if (!manifest.existsSync()) return;
  final json = manifest.readAsStringSync();
  final semver = match.group(1)!;
  final build = match.group(2)!;
  if (!json.contains('"semanticVersion": "$semver"')) {
    failures.add('manifest semanticVersion != pubspec $semver');
  }
  if (!json.contains('"buildNumber": $build')) {
    failures.add('manifest buildNumber != pubspec +$build');
  }
}

void _checkLegalLinks(String root, List<String> failures) {
  const required = [
    'https://archiveme.app/privacy',
    'https://archiveme.app/contact',
  ];
  final sources = [
    File('$root/lib/config/app_config.dart'),
    File('$root/lib/product/customer_language.dart'),
  ];
  final combined = sources
      .where((f) => f.existsSync())
      .map((f) => f.readAsStringSync())
      .join('\n');
  if (combined.isEmpty) {
    failures.add('missing app_config.dart / customer_language.dart for legal URLs');
    return;
  }
  for (final url in required) {
    if (!combined.contains(url)) {
      failures.add('production config missing legal/support URL: $url');
    }
  }
}

void _checkApiHost(String root, List<String> failures) {
  final config = File('$root/lib/config/app_config.dart');
  if (!config.existsSync()) return;
  final text = config.readAsStringSync();
  final match = RegExp(r"productionApiBaseUrl\s*=\s*'([^']+)'").firstMatch(text);
  final url = match?.group(1) ?? '';
  if (url.startsWith('http://')) {
    failures.add('production API host uses insecure http://');
  }
  if (url.isEmpty) {
    failures.add('production API base URL is empty');
  }
}
