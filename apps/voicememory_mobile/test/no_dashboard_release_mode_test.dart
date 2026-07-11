import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/no_dashboard_positioning/no_dashboard_positioning_guard.dart';
import 'package:voicememory_mobile/features/no_dashboard_release_mode/no_dashboard_release_mode.dart';
import 'package:voicememory_mobile/features/no_dashboard_release_mode/no_dashboard_release_mode_copy.dart';
import 'package:voicememory_mobile/features/v1_visible_surface_reducer/v1_visible_surface_reducer.dart';

const _docsPath = 'docs/NO_DASHBOARD_RELEASE_MODE.md';

NoDashboardReleaseModeInput _input({
  bool releaseMode = true,
  bool postSaveImmediate = false,
  bool firstProofSafe = false,
  bool afterFirstProof = false,
  bool confirmedRepeatOrEligibleMoment = false,
  bool proofValueSeen = false,
  bool userExplicitlyAsked = false,
  bool proofThresholdStillThree = true,
}) =>
    NoDashboardReleaseModeInput(
      releaseMode: releaseMode,
      postSaveImmediate: postSaveImmediate,
      firstProofSafe: firstProofSafe,
      afterFirstProof: afterFirstProof,
      confirmedRepeatOrEligibleMoment: confirmedRepeatOrEligibleMoment,
      proofValueSeen: proofValueSeen,
      userExplicitlyAsked: userExplicitlyAsked,
      proofThresholdStillThree: proofThresholdStillThree,
    );

NoDashboardReleaseSurfaceResult _surface(
  NoDashboardReleaseModeResult result,
  NoDashboardReleaseSurface surface,
) =>
    result.surface(surface);

void main() {
  group('NoDashboardReleaseMode.build', () {
    test('tracks risky and allowed surface sets', () {
      expect(NoDashboardReleaseMode.riskySurfaceCount, 9);
      expect(NoDashboardReleaseMode.allowedSurfaceCount, 9);
      expect(NoDashboardReleaseMode.riskySurfaces, hasLength(9));
      expect(NoDashboardReleaseMode.allowedSurfaces, hasLength(9));
    });

    test('dashboard surfaces hidden in release mode', () {
      final result = NoDashboardReleaseMode.build(_input());
      for (final surface in NoDashboardReleaseMode.riskySurfaces) {
        expect(
          _surface(result, surface).visible,
          isFalse,
          reason: surface.name,
        );
      }
      expect(result.riskyHiddenInRelease, isTrue);
      expect(result.decision, NoDashboardReleaseModeDecision.hardened);
    });

    test('proof trail surfaces allowed', () {
      final result = NoDashboardReleaseMode.build(
        _input(
          firstProofSafe: true,
          afterFirstProof: true,
          confirmedRepeatOrEligibleMoment: true,
          proofValueSeen: true,
        ),
      );

      for (final surface in [
        NoDashboardReleaseSurface.record,
        NoDashboardReleaseSurface.typeInstead,
        NoDashboardReleaseSurface.promptAssist,
        NoDashboardReleaseSurface.firstProof,
        NoDashboardReleaseSurface.whyProofAppeared,
        NoDashboardReleaseSurface.confirmCorrect,
        NoDashboardReleaseSurface.whatChanged,
        NoDashboardReleaseSurface.proLongerTrail,
      ]) {
        expect(
          _surface(result, surface).visible,
          isTrue,
          reason: surface.name,
        );
      }
    });

    test('user asked can allow low-risk secondary surface', () {
      final hidden = NoDashboardReleaseMode.build(_input());
      final shown = NoDashboardReleaseMode.build(
        _input(userExplicitlyAsked: true),
      );

      expect(
        _surface(hidden, NoDashboardReleaseSurface.shareProof).visible,
        isFalse,
      );
      expect(
        _surface(shown, NoDashboardReleaseSurface.shareProof).visible,
        isTrue,
      );
      expect(
        _surface(shown, NoDashboardReleaseSurface.dashboard).visible,
        isFalse,
      );
    });

    test('post-save reinforcement shows immediately after save', () {
      final hidden = NoDashboardReleaseMode.build(_input());
      final shown = NoDashboardReleaseMode.build(
        _input(postSaveImmediate: true),
      );
      expect(
        _surface(hidden, NoDashboardReleaseSurface.postSaveReinforcement)
            .visible,
        isFalse,
      );
      expect(
        _surface(shown, NoDashboardReleaseSurface.postSaveReinforcement)
            .visible,
        isTrue,
      );
    });

    test('report exposes canonical copy', () {
      final report = NoDashboardReleaseMode.report(
        NoDashboardReleaseMode.build(_input()),
      );
      expect(report.headline, NoDashboardReleaseModeCopy.headline);
      expect(report.guardrail, NoDashboardReleaseModeCopy.guardrail);
    });
  });

  group('NoDashboardReleaseMode.passesReleaseCopy', () {
    test('copy blocks dashboard second brain and life OS', () {
      expect(
        NoDashboardReleaseMode.passesReleaseCopy(
          'ArchiveMe is your life dashboard.',
        ),
        isFalse,
      );
      expect(
        NoDashboardReleaseMode.passesReleaseCopy(
          'ArchiveMe is your second brain.',
        ),
        isFalse,
      );
      expect(
        NoDashboardReleaseMode.passesReleaseCopy(
          'ArchiveMe is your life OS.',
        ),
        isFalse,
      );
      expect(
        NoDashboardReleaseMode.passesReleaseCopy(
          'ArchiveMe keeps your proof trail over time.',
        ),
        isTrue,
      );
      expect(
        NoDashboardReleaseMode.passesReleaseCopy(
          NoDashboardReleaseModeCopy.guardrail,
        ),
        isTrue,
      );
    });

    test('proof trail language allowed', () {
      expect(
        NoDashboardPositioningGuard.containsPreferredProofTrailLanguage(
          'See the first useful proof after a few saves.',
        ),
        isTrue,
      );
    });
  });

  group('NoDashboardReleaseMode.fromReducerInput', () {
    test('maps reducer proof gates into release mode input', () {
      final input = NoDashboardReleaseMode.fromReducerInput(
        releaseMode: true,
        reducerInput: const V1VisibleSurfaceReducerInput(
          firstProofSafe: true,
          afterFirstProof: true,
          proofThresholdStillThree: true,
        ),
      );
      final result = NoDashboardReleaseMode.build(input);
      expect(
        _surface(result, NoDashboardReleaseSurface.firstProof).visible,
        isTrue,
      );
    });
  });

  group('protected regression', () {
    test('no record layout changes', () {
      final recordSource =
          File('lib/screens/record_screen.dart').readAsStringSync();
      expect(
        NoDashboardReleaseMode.detectRecordLayoutUnchanged(recordSource),
        isTrue,
      );
      expect(
        V1VisibleSurfaceReducer.detectRecordLayoutUnchanged(recordSource),
        isTrue,
      );
    });

    test('release mode hook exists in production navigation', () {
      final source =
          File('lib/config/production_navigation.dart').readAsStringSync();
      expect(NoDashboardReleaseMode.detectReleaseModeHook(source), isTrue);
    });

    test('module does not import widgets or screens', () {
      final source = File(
        'lib/features/no_dashboard_release_mode/no_dashboard_release_mode.dart',
      ).readAsStringSync();
      for (final line in source.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('import ')) continue;
        expect(trimmed.contains('widgets/'), isFalse);
        expect(trimmed.contains('screens/'), isFalse);
        expect(trimmed.contains('package:flutter/'), isFalse);
      }
    });

    test('docs include risky and allowed surfaces', () {
      final docs = File(_docsPath).readAsStringSync();
      expect(docs, contains('## Risky surfaces'));
      expect(docs, contains('## Allowed surfaces'));
      for (final surface in NoDashboardReleaseMode.riskySurfaces) {
        expect(
          docs,
          contains(NoDashboardReleaseModeCopy.labelFor(surface)),
          reason: surface.name,
        );
      }
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final text in NoDashboardReleaseModeCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });
}
