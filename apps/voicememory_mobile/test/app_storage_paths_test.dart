import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/storage/app_storage_paths.dart';

void main() {
  group('looksLikeIosSimulatorEnvironment', () {
    test('detects CoreSimulator home path', () {
      expect(
        AppStoragePaths.looksLikeIosSimulatorEnvironment(
          environment: {
            'HOME':
                '/Users/dev/Library/Developer/CoreSimulator/Devices/ABC/data',
          },
        ),
        isTrue,
      );
    });

    test('detects SIMULATOR_DEVICE_NAME', () {
      expect(
        AppStoragePaths.looksLikeIosSimulatorEnvironment(
          environment: {'SIMULATOR_DEVICE_NAME': 'iPad Pro 13-inch'},
        ),
        isTrue,
      );
    });

    test('returns false for non-iOS', () {
      expect(
        AppStoragePaths.looksLikeIosSimulatorEnvironment(
          isIos: false,
          environment: {'HOME': '/Users/dev/Library/Developer/CoreSimulator'},
        ),
        isFalse,
      );
    });

    test('returns false for physical-like environment', () {
      expect(
        AppStoragePaths.looksLikeIosSimulatorEnvironment(
          environment: {'HOME': '/var/mobile'},
        ),
        isFalse,
      );
    });
  });

  group('debug simulator fallback directories', () {
    late Directory tempRoot;
    final logs = <String>[];

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('archiveme_paths_test_');
      logs.clear();
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('documents fallback uses archiveme_sim_docs under system temp', () {
      final dir = AppStoragePaths.debugSimulatorDocumentsDirectorySync(
        systemTemp: tempRoot,
        log: logs.add,
      );

      expect(dir.path, '${tempRoot.path}/archiveme_sim_docs');
      expect(dir.existsSync(), isTrue);
      expect(logs, contains(AppStoragePaths.simulatorFallbackLog));
      expect(AppStoragePaths.usedSimulatorFallback, isTrue);
    });

    test('temporary fallback uses archiveme_sim_tmp under system temp', () {
      final dir = AppStoragePaths.debugSimulatorTemporaryDirectorySync(
        systemTemp: tempRoot,
        log: logs.add,
      );

      expect(dir.path, '${tempRoot.path}/archiveme_sim_tmp');
      expect(dir.existsSync(), isTrue);
      expect(logs, contains(AppStoragePaths.simulatorFallbackLog));
    });

    test('fallback logs reason when provided', () {
      AppStoragePaths.debugSimulatorDocumentsDirectorySync(
        systemTemp: tempRoot,
        log: logs.add,
        reason: 'native assets missing',
      );

      expect(
        logs.any((line) => line.contains('reason=native assets missing')),
        isTrue,
      );
    });
  });
}
