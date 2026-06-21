import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/debug/archive_activation_scripted_e2e_gate.dart';
import 'package:voicememory_mobile/features/debug/archive_beta_debug_gate.dart';
import 'package:voicememory_mobile/features/loop_map/loop_map_primary_surface.dart';
import 'package:voicememory_mobile/features/onboarding/archive_loop_onboarding.dart';
import 'package:voicememory_mobile/screens/archive_loop_onboarding_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  tearDown(ArchiveBetaDebugGate.resetForTest);

  group('ArchiveBetaDebugGate', () {
    test('showLoopDebugControls is false when release override is set', () {
      ArchiveBetaDebugGate.visibleOverride = false;
      expect(ArchiveBetaDebugGate.showLoopDebugControls, isFalse);
    });

    test('showLoopDebugControls is false when ARCHIVEME_RELEASE_SMOKE is set',
        () {
      // Compile-time define is false in unit tests; release smoke script sets true.
      expect(
        const bool.fromEnvironment('ARCHIVEME_RELEASE_SMOKE', defaultValue: false),
        isFalse,
      );
      ArchiveBetaDebugGate.visibleOverride = false;
      expect(ArchiveBetaDebugGate.showLoopDebugControls, isFalse);
    });

    test('debug control keys are registered for release audits', () {
      expect(ArchiveBetaDebugGate.debugControlKeys, containsAll([
        'debug_enable_archive_loop_pro',
        'debug_reset_archive_loop_onboarding',
        'debug_export_loop_map_validation',
    'debug_export_paid_intent_feedback',
        'debug_export_beta_evidence',
        'debug_clear_beta_evidence',
        'debug_export_activation_funnel',
        'debug_copy_launch_readiness',
        'debug_force_return_hook_due',
        'debug_save_onboarding_scripted_moment',
      ]));
    });
  });

  group('Archive loop debug UI source gates', () {
    final gatedFiles = <String, List<String>>{
      'lib/screens/record_screen.dart': [
        'debug_force_return_hook_due',
        'debug_save_onboarding_scripted_moment',
      ],
      'lib/screens/archive_loop_onboarding_screen.dart': [
        'debug_reset_archive_loop_onboarding',
        ArchiveActivationScriptedE2EGate.debugConfirmFirstNodeKey,
      ],
      'lib/screens/loop_mode_screen.dart': ['debug_enable_archive_loop_pro'],
      'lib/screens/archive_loop_paywall_screen.dart': [
        'archive_loop_debug_unlock_pro_button',
      ],
      'lib/widgets/patterns/loop_map_validation_probe_card.dart': [
        'debug_export_loop_map_validation',
    'debug_export_paid_intent_feedback',
      ],
      'lib/widgets/beta/archive_beta_evidence_dashboard_card.dart': [
        'debug_export_activation_funnel',
      ],
    };

    for (final entry in gatedFiles.entries) {
      test('${entry.key} hides ${entry.value.join(', ')} behind beta gate', () {
        final source = File(entry.key).readAsStringSync();
        for (final key in entry.value) {
          expect(source, contains("Key('$key')"));
          final keyIndex = source.indexOf("Key('$key')");
          final windowStart = keyIndex > 400 ? keyIndex - 400 : 0;
          final window = source.substring(windowStart, keyIndex);
          final gateNeedle = key == ArchiveActivationScriptedE2EGate.debugConfirmFirstNodeKey
              ? 'ArchiveActivationScriptedE2EGate.showDebugConfirmFirstNodeButton'
              : 'ArchiveBetaDebugGate.showLoopDebugControls';
          expect(
            window,
            contains(gateNeedle),
            reason: '$key must be wrapped in $gateNeedle',
          );
        }
      });
    }

    test('scripted moment save is gated in coordinator', () {
      final source = File(
        'lib/features/onboarding/archive_loop_onboarding.dart',
      ).readAsStringSync();
      expect(source, contains('ArchiveBetaDebugGate.showLoopDebugControls'));
    });

    test('force return hook due is gated in reminder store', () {
      final source = File(
        'lib/features/archive_reactivity/archive_lens_return_hook_reminder.dart',
      ).readAsStringSync();
      expect(source, contains('ArchiveBetaDebugGate.showLoopDebugControls'));
    });

    test('app review access is gated by review mode dart-define', () {
      final source = File(
        'lib/widgets/settings/app_review_access_settings_section.dart',
      ).readAsStringSync();
      expect(source, contains("Key('archive_app_review_access_section')"));
      expect(source, contains('ArchiveAppReviewAccessGate.isEnabled'));
      expect(source, isNot(contains('ArchiveBetaDebugGate')));
    });
  });

  group('Archive loop debug UI widgets', () {
    testWidgets('onboarding debug reset is hidden when gate is closed', (
      tester,
    ) async {
      ArchiveBetaDebugGate.visibleOverride = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ArchiveLoopOnboardingScreen(),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('debug_reset_archive_loop_onboarding')),
        findsNothing,
      );
      expect(
        find.text(ArchiveLoopOnboardingCopy.introTitle),
        findsOneWidget,
      );
    });
  });

  group('App Store copy safety', () {
    test('store listing avoids diagnosis therapy and medical claims', () {
      final copy = File('docs/APP_STORE_COPY.md').readAsStringSync().toLowerCase();
      const banned = [
        'diagnosis',
        'diagnose',
        'therapy',
        'therapist',
        'medical treatment',
        'mental health improvement',
        'guaranteed',
        'cure',
        'treatment',
      ];
      for (final word in banned) {
        expect(copy, isNot(contains(word)), reason: 'APP_STORE_COPY mentions $word');
      }
    });

    test('Info.plist microphone copy is user-friendly', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        plist,
        contains(
          'ArchiveMe uses the microphone so you can record short private reflections.',
        ),
      );
    });
  });
}
