import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/sync_expectation_safety/sync_expectation_safety_copy.dart';
import 'package:voicememory_mobile/features/sync_expectation_safety/sync_expectation_safety_guard.dart';

const _docsPath = 'docs/SYNC_EXPECTATION_SAFETY_GUARD.md';
const _guardPath =
    'lib/features/sync_expectation_safety/sync_expectation_safety_guard.dart';

void main() {
  group('SyncExpectationSafetyGuard.evaluate', () {
    test('cloud backup blocked when sync not proven', () {
      final result = SyncExpectationSafetyGuard.evaluate(
        'Pro includes cloud backup for your archive.',
      );
      expect(result.action, SyncExpectationSafetyAction.blocked);
      expect(result.reason, SyncExpectationSafetyBlockReason.cloudBackup);
      expect(
        SyncExpectationSafetyGuard.passes(
          'Pro includes cloud backup for your archive.',
        ),
        isFalse,
      );
    });

    test('cross-device sync blocked when sync not proven', () {
      final result = SyncExpectationSafetyGuard.evaluate(
        'Keep cross-device sync across phone and iPad.',
      );
      expect(result.action, SyncExpectationSafetyAction.blocked);
      expect(result.reason, SyncExpectationSafetyBlockReason.crossDeviceSync);
    });

    test('local/on-device copy allowed', () {
      for (final copy in [
        'Your local archive stays private on this device.',
        'Saved on this device until you export.',
      ]) {
        final result = SyncExpectationSafetyGuard.evaluate(copy);
        expect(
          result.action,
          SyncExpectationSafetyAction.allowed,
          reason: copy,
        );
        expect(
          SyncExpectationSafetyGuard.containsAllowedLanguage(copy),
          isTrue,
          reason: copy,
        );
      }
    });

    test('Pro trail copy allowed', () {
      const copy = 'Pro keeps the longer proof trail as your archive grows.';
      final result = SyncExpectationSafetyGuard.evaluate(copy);
      expect(result.action, SyncExpectationSafetyAction.allowed);
      expect(SyncExpectationSafetyGuard.containsAllowedLanguage(copy), isTrue);
    });

    test('sync not available yet is honest TestFlight copy', () {
      const copy = 'Sync not available yet. Your archive stays on this device.';
      final result = SyncExpectationSafetyGuard.evaluate(copy);
      expect(result.action, SyncExpectationSafetyAction.allowed);
      expect(result.usesAllowedLanguage, isTrue);
    });

    test('blocked phrases allowed when sync proven', () {
      expect(
        SyncExpectationSafetyGuard.passes(
          'Cloud backup keeps your archive safe across devices.',
          syncProven: true,
        ),
        isTrue,
      );
    });

    test('negated cloud backup guidance allowed', () {
      const copy = 'Do not claim cloud backup in this TestFlight build.';
      final result = SyncExpectationSafetyGuard.evaluate(copy);
      expect(result.action, SyncExpectationSafetyAction.allowed);
    });

    test('other blocked sync promises stay blocked', () {
      final cases = <(String, SyncExpectationSafetyBlockReason)>[
        (
          'Access everywhere with your account.',
          SyncExpectationSafetyBlockReason.accessEverywhere,
        ),
        (
          'Never lose your archive again.',
          SyncExpectationSafetyBlockReason.neverLoseArchive,
        ),
        (
          'Your archive is backed up automatically.',
          SyncExpectationSafetyBlockReason.backedUpAutomatically,
        ),
        (
          'Your account keeps your trail safe in the cloud.',
          SyncExpectationSafetyBlockReason.accountKeepsTrailSafe,
        ),
        (
          'Sync across devices when you sign in.',
          SyncExpectationSafetyBlockReason.syncAcrossDevices,
        ),
      ];

      for (final (copy, reason) in cases) {
        final result = SyncExpectationSafetyGuard.evaluate(copy);
        expect(
          result.action,
          SyncExpectationSafetyAction.blocked,
          reason: copy,
        );
        expect(result.reason, reason, reason: copy);
      }
    });
  });

  group('protected regression', () {
    late String guardSource;

    setUpAll(() {
      guardSource = File(_guardPath).readAsStringSync();
    });

    test('docs describe copy-guard-only scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('copy guard only'));
      expect(doc, contains('no backend'));
      expect(doc, contains('longer proof trail'));
      expect(doc, contains('testflight'));
    });

    test('guardrail forbids backend implementation', () {
      final guardrail = SyncExpectationSafetyCopy.guardrail.toLowerCase();
      expect(guardrail, contains('copy guard only'));
      expect(guardrail, contains('no backend'));
      expect(guardrail, contains('longer proof trail'));
    });

    test('no backend imports', () {
      expect(
        SyncExpectationSafetyGuard.detectNoBackendImports(guardSource),
        isTrue,
      );
      expect(
        SyncExpectationSafetyGuard.detectCopyGuardOnly(guardSource),
        isTrue,
      );
      for (final path in [
        _guardPath,
        'lib/features/sync_expectation_safety/sync_expectation_safety_copy.dart',
      ]) {
        final importLines = File(path)
            .readAsStringSync()
            .split('\n')
            .where((line) => line.trim().startsWith('import '));
        for (final line in importLines) {
          expect(line.contains('package:firebase'), isFalse, reason: line);
          expect(line.contains('package:supabase'), isFalse, reason: line);
          expect(line.contains('../api/'), isFalse, reason: line);
        }
      }
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in SyncExpectationSafetyCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('advice guard registers sync expectation safety copy', () {
      final guardRegistry = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardRegistry,
        contains('SyncExpectationSafetyCopy.allVisibleStrings()'),
      );
    });
  });
}
