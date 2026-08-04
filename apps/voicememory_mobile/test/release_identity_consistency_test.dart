import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/config/release_identity.dart';

/// Files that may mention the immutable legacy-prefix RevenueCat product SKUs.
const _legacyIdAllowlist = {
  'docs/REVENUECAT_RELEASE_CHECKLIST.md',
  'REVENUECAT_LAUNCH_BLOCKERS.md',
  'lib/billing/revenuecat_configuration.dart',
  'tool/validate_revenuecat_configuration.sh',
};

const _activeConfigPaths = [
  'lib/config/app_config.dart',
  'lib/push/firebase_options.dart',
  'android/app/build.gradle.kts',
  'ios/Runner.xcodeproj/project.pbxproj',
  'ios/Runner/Info.plist',
  'ios/Runner/Runner.entitlements',
  'ios/TodayCheckWidget/TodayCheckWidgetExtension.entitlements',
  'ios/TodayCheckWidget/TodayCheckWidget.swift',
  'ios/Runner/ObjectiveWidgetStorage.swift',
  'android/app/src/main/kotlin/com/voicememory/mobile/MainActivity.kt',
  'android/app/src/main/kotlin/com/voicememory/mobile/widget/ObjectiveWidgetStorage.kt',
  'android/app/src/main/kotlin/com/voicememory/mobile/widget/TodayCheckWidgetProvider.kt',
  'README.md',
  'docs/IOS_RELEASE_CHECKLIST.md',
  'docs/ANDROID_RELEASE_CHECKLIST.md',
];

const _canonicalBundleId = ReleaseIdentity.applicationId;
const _canonicalAppGroup = ReleaseIdentity.appGroupId;
const _legacyBundleId = 'com.voicememory.app';

void main() {
  group('Release identity constants', () {
    test('AppConfig uses ArchiveMe and com.voicememory.mobile', () {
      expect(AppConfig.appName, 'ArchiveMe');
      expect(AppConfig.bundleId, _canonicalBundleId);
    });
  });

  group('Android release identity', () {
    test('build.gradle.kts namespace and applicationId are canonical', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('namespace = "$_canonicalBundleId"'));
      expect(gradle, contains('applicationId = "$_canonicalBundleId"'));
      expect(gradle, isNot(contains(_legacyBundleId)));
    });

    test('MainActivity kotlin package matches namespace', () {
      final main = File(
        'android/app/src/main/kotlin/com/voicememory/mobile/MainActivity.kt',
      ).readAsStringSync();
      expect(main, contains('package $_canonicalBundleId'));
      expect(main, isNot(contains('package $_legacyBundleId')));
    });
  });

  group('iOS release identity', () {
    test('Runner PRODUCT_BUNDLE_IDENTIFIER is canonical', () {
      final pbxproj = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(
        pbxproj,
        contains('PRODUCT_BUNDLE_IDENTIFIER = $_canonicalBundleId;'),
      );
      expect(
        pbxproj,
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = $_canonicalBundleId.RunnerTests;',
        ),
      );
      expect(pbxproj, isNot(contains('$_legacyBundleId.RunnerTests')));
    });

    test('Info.plist display name and URL schemes', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<string>ArchiveMe</string>'));
      expect(plist, contains('<string>archiveme</string>'));
      expect(plist, contains('<string>voicememory</string>'));
    });

    test('App Group entitlements use group.com.voicememory.mobile', () {
      for (final path in [
        'ios/Runner/Runner.entitlements',
        'ios/TodayCheckWidget/TodayCheckWidgetExtension.entitlements',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text, contains(_canonicalAppGroup));
        expect(text, isNot(contains('group.$_legacyBundleId')));
      }
    });

    test('Swift widget storage uses canonical app group', () {
      for (final path in [
        'ios/Runner/ObjectiveWidgetStorage.swift',
        'ios/TodayCheckWidget/TodayCheckWidget.swift',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text, contains(_canonicalAppGroup));
      }
    });
  });

  group('Docs and branding', () {
    test('README states ArchiveMe public name and canonical bundle id', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme, contains('ArchiveMe'));
      expect(readme, contains(_canonicalBundleId));
      expect(readme, contains('Runner.xcworkspace'));
    });

    test('release checklists document canonical ids', () {
      final ios = File('docs/IOS_RELEASE_CHECKLIST.md').readAsStringSync();
      final android = File(
        'docs/ANDROID_RELEASE_CHECKLIST.md',
      ).readAsStringSync();
      expect(ios, contains(_canonicalBundleId));
      expect(ios, contains('archiveme://'));
      expect(android, contains(_canonicalBundleId));
    });
  });

  group('Legacy id hygiene', () {
    test('active config files do not use com.voicememory.app', () {
      for (final relative in _activeConfigPaths) {
        final text = File(relative).readAsStringSync();
        expect(
          text.contains(_legacyBundleId),
          isFalse,
          reason: '$relative must not contain legacy id',
        );
      }
    });

    test('legacy id only appears in tiny allowlisted docs if at all', () {
      final mobileRoot = Directory('.');
      final offenders = <String>[];

      for (final entity in mobileRoot.listSync(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (path.contains('/build/') ||
            path.contains('/.dart_tool/') ||
            path.contains('/Pods/')) {
          continue;
        }
        if (!path.endsWith('.dart') &&
            !path.endsWith('.kts') &&
            !path.endsWith('.kt') &&
            !path.endsWith('.swift') &&
            !path.endsWith('.plist') &&
            !path.endsWith('.entitlements') &&
            !path.endsWith('.pbxproj') &&
            !path.endsWith('.md') &&
            !path.endsWith('.sh')) {
          continue;
        }
        final relative = path.startsWith('./') ? path.substring(2) : path;
        if (relative.startsWith('test/') ||
            relative == 'test/release_identity_consistency_test.dart') {
          continue;
        }
        if (relative.startsWith('ios/Flutter/')) continue;
        final text = entity.readAsStringSync();
        if (!text.contains(_legacyBundleId)) continue;
        if (_legacyIdAllowlist.contains(relative)) continue;
        offenders.add(relative);
      }

      expect(
        offenders,
        isEmpty,
        reason: 'unexpected legacy id in: ${offenders.join(', ')}',
      );
    });
  });
}
