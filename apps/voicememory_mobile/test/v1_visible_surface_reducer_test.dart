import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/v1_visible_surface_reducer/v1_visible_surface_reducer.dart';
import 'package:voicememory_mobile/features/v1_visible_surface_reducer/v1_visible_surface_reducer_copy.dart';

const _docsPath = 'docs/V1_VISIBLE_SURFACE_REDUCER.md';

V1VisibleSurfaceReducerInput _input({
  bool postSaveImmediate = false,
  bool firstProofSafe = false,
  bool afterFirstProof = false,
  bool confirmedRepeatOrEligibleMoment = false,
  bool proofValueSeen = false,
  bool userExplicitlyAsked = false,
  bool developerMode = false,
  bool proofThresholdStillThree = true,
}) =>
    V1VisibleSurfaceReducerInput(
      postSaveImmediate: postSaveImmediate,
      firstProofSafe: firstProofSafe,
      afterFirstProof: afterFirstProof,
      confirmedRepeatOrEligibleMoment: confirmedRepeatOrEligibleMoment,
      proofValueSeen: proofValueSeen,
      userExplicitlyAsked: userExplicitlyAsked,
      developerMode: developerMode,
      proofThresholdStillThree: proofThresholdStillThree,
    );

V1VisibleSurfaceReducerSurfaceResult _surface(
  V1VisibleSurfaceReducerResult result,
  V1Surface surface,
) =>
    result.surface(surface);

void main() {
  group('V1VisibleSurfaceReducer.build', () {
    test('tracks twenty-five canonical surfaces', () {
      final result = V1VisibleSurfaceReducer.build(_input());
      expect(result.surfaces.length, V1VisibleSurfaceReducer.surfaceCount);
      expect(V1Surface.values.length, V1VisibleSurfaceReducer.surfaceCount);
    });

    test('core surfaces show', () {
      final result = V1VisibleSurfaceReducer.build(_input());
      for (final surface in [
        V1Surface.recordCapture,
        V1Surface.typeInstead,
        V1Surface.promptAssist,
        V1Surface.restorePurchases,
        V1Surface.privacySupport,
        V1Surface.archiveHome,
      ]) {
        expect(_surface(result, surface).visible, isTrue, reason: surface.name);
        expect(
          _surface(result, surface).decision,
          V1SurfaceDecision.showCore,
          reason: surface.name,
        );
      }
    });

    test('post-save reinforcement shows immediately after save', () {
      final hidden = V1VisibleSurfaceReducer.build(_input());
      final shown = V1VisibleSurfaceReducer.build(
        _input(postSaveImmediate: true),
      );
      expect(
        _surface(hidden, V1Surface.postSaveReinforcement).visible,
        isFalse,
      );
      expect(
        _surface(shown, V1Surface.postSaveReinforcement).visible,
        isTrue,
      );
    });

    test('restore and privacy allowed as release essentials', () {
      final result = V1VisibleSurfaceReducer.build(_input());
      expect(_surface(result, V1Surface.restorePurchases).visible, isTrue);
      expect(_surface(result, V1Surface.privacySupport).visible, isTrue);
    });

    test('first proof is gated until proof guard is safe', () {
      final blocked = V1VisibleSurfaceReducer.build(_input());
      final allowed = V1VisibleSurfaceReducer.build(
        _input(firstProofSafe: true),
      );
      expect(_surface(blocked, V1Surface.firstProof).visible, isFalse);
      expect(_surface(allowed, V1Surface.firstProof).visible, isTrue);
    });

    test('pro trail gated until proof value', () {
      final blocked = V1VisibleSurfaceReducer.build(_input());
      final afterProof = V1VisibleSurfaceReducer.build(
        _input(afterFirstProof: true),
      );
      final proofValue = V1VisibleSurfaceReducer.build(
        _input(proofValueSeen: true),
      );
      expect(_surface(blocked, V1Surface.proLongerTrail).visible, isFalse);
      expect(_surface(afterProof, V1Surface.proLongerTrail).visible, isTrue);
      expect(_surface(proofValue, V1Surface.proLongerTrail).visible, isTrue);
    });

    test('why proof and confirm correct only after first proof', () {
      final blocked = V1VisibleSurfaceReducer.build(_input());
      final allowed = V1VisibleSurfaceReducer.build(
        _input(afterFirstProof: true),
      );
      for (final surface in [
        V1Surface.whyProofAppeared,
        V1Surface.confirmCorrect,
      ]) {
        expect(_surface(blocked, surface).visible, isFalse, reason: surface.name);
        expect(_surface(allowed, surface).visible, isTrue, reason: surface.name);
      }
    });

    test('what changed only after confirmed repeat', () {
      final blocked = V1VisibleSurfaceReducer.build(
        _input(afterFirstProof: true),
      );
      final allowed = V1VisibleSurfaceReducer.build(
        _input(
          afterFirstProof: true,
          confirmedRepeatOrEligibleMoment: true,
        ),
      );
      expect(_surface(blocked, V1Surface.whatChanged).visible, isFalse);
      expect(_surface(allowed, V1Surface.whatChanged).visible, isTrue);
    });

    test('dashboard hidden for V1', () {
      final result = V1VisibleSurfaceReducer.build(_input());
      expect(_surface(result, V1Surface.dashboard).visible, isFalse);
      expect(
        _surface(result, V1Surface.dashboard).decision,
        V1SurfaceDecision.hideForV1,
      );
    });

    test('reports hidden for V1', () {
      expect(
        _surface(
          V1VisibleSurfaceReducer.build(_input()),
          V1Surface.reports,
        ).visible,
        isFalse,
      );
    });

    test('action items hidden for V1', () {
      expect(
        _surface(
          V1VisibleSurfaceReducer.build(_input()),
          V1Surface.actionItems,
        ).visible,
        isFalse,
      );
    });

    test('archive packs hidden for V1', () {
      expect(
        _surface(
          V1VisibleSurfaceReducer.build(_input()),
          V1Surface.archivePacks,
        ).visible,
        isFalse,
      );
    });

    test('widgets hidden for V1', () {
      expect(
        _surface(
          V1VisibleSurfaceReducer.build(_input()),
          V1Surface.widgets,
        ).visible,
        isFalse,
      );
    });

    test('archive analyst hidden for V1', () {
      expect(
        _surface(
          V1VisibleSurfaceReducer.build(_input()),
          V1Surface.archiveAnalyst,
        ).visible,
        isFalse,
      );
    });

    test('evidence map hidden in first journey', () {
      expect(
        _surface(
          V1VisibleSurfaceReducer.build(_input()),
          V1Surface.evidenceMap,
        ).visible,
        isFalse,
      );
    });

    test('developer diagnostics developerOnly', () {
      final hidden = V1VisibleSurfaceReducer.build(_input());
      final shown = V1VisibleSurfaceReducer.build(
        _input(developerMode: true),
      );
      expect(
        _surface(hidden, V1Surface.developerDiagnostics).decision,
        V1SurfaceDecision.developerOnly,
      );
      expect(
        _surface(hidden, V1Surface.developerDiagnostics).visible,
        isFalse,
      );
      expect(
        _surface(shown, V1Surface.developerDiagnostics).visible,
        isTrue,
      );
    });

    test('share proof only when user explicitly asks', () {
      final hidden = V1VisibleSurfaceReducer.build(_input());
      final shown = V1VisibleSurfaceReducer.build(
        _input(userExplicitlyAsked: true),
      );
      expect(_surface(hidden, V1Surface.shareProof).visible, isFalse);
      expect(_surface(shown, V1Surface.shareProof).visible, isTrue);
    });

    test('keeps V1 small hides all secondary surfaces', () {
      final result = V1VisibleSurfaceReducer.build(_input());
      expect(result.keepsV1Small, isTrue);
      expect(result.hiddenCount, V1VisibleSurfaceReducer.hiddenSurfaces.length);
    });
  });

  group('V1VisibleSurfaceReducer.fromRepoSignals', () {
    test('repo proof threshold stays at three', () {
      final gateSource = File(
        'lib/features/archive_evidence/archive_evidence_quality_gate.dart',
      ).readAsStringSync();
      expect(
        V1VisibleSurfaceReducer.detectProofThresholdStillThree(gateSource),
        isTrue,
      );
      expect(ArchiveEvidenceQualityGate.minProofEntryCount, 3);
    });
  });

  group('protected regression', () {
    test('module does not import RevenueCat purchase or restore', () {
      for (final path in [
        'lib/features/v1_visible_surface_reducer/v1_visible_surface_reducer.dart',
        'lib/features/v1_visible_surface_reducer/v1_visible_surface_reducer_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('revenuecat_service'), isFalse);
        expect(source.contains('billing/paywall'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
      }
    });

    test('no proof threshold changes in reducer module', () {
      final source = File(
        'lib/features/v1_visible_surface_reducer/v1_visible_surface_reducer.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'^\s*static const minProofEntryCount', multiLine: true)
            .hasMatch(source),
        isFalse,
      );
      expect(
        source.contains('ArchiveEvidenceQualityGate.minProofEntryCount'),
        isTrue,
      );
      expect(
        V1VisibleSurfaceReducer.detectProofThresholdStillThree(
          File(
            'lib/features/archive_evidence/archive_evidence_quality_gate.dart',
          ).readAsStringSync(),
        ),
        isTrue,
      );
    });

    test('no record layout changes in reducer module', () {
      final reducerSource = File(
        'lib/features/v1_visible_surface_reducer/v1_visible_surface_reducer.dart',
      ).readAsStringSync();
      final recordSource =
          File('lib/screens/record_screen.dart').readAsStringSync();
      expect(reducerSource.contains('screens/record_screen.dart'), isFalse);
      expect(
        V1VisibleSurfaceReducer.detectRecordLayoutUnchanged(recordSource),
        isTrue,
      );
    });

    test('docs describe reducer-only scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('do not delete features'));
      expect(doc, contains('proof trail'));
      expect(doc, contains('hideforv1'));
    });

    test('copy protects small V1', () {
      expect(V1VisibleSurfaceReducerCopy.headline, 'Keep V1 small');
      expect(
        V1VisibleSurfaceReducerCopy.guardrail.toLowerCase(),
        contains('do not delete features'),
      );
    });

    test('copy uses proof trail language', () {
      final joined =
          V1VisibleSurfaceReducerCopy.allVisibleStrings().join('\n').toLowerCase();
      expect(joined, contains('proof trail'));
      expect(joined, contains('first proof'));
      expect(joined, contains('save one repeat'));
    });

    test('copy avoids dashboard story storage as primary language', () {
      final primary = [
        V1VisibleSurfaceReducerCopy.headline,
        V1VisibleSurfaceReducerCopy.body,
        V1VisibleSurfaceReducerCopy.coreLine,
      ].join('\n').toLowerCase();
      expect(primary, isNot(contains('dashboard')));
      expect(primary, isNot(contains('storage')));
      expect(primary, isNot(contains('story')));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in V1VisibleSurfaceReducerCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });
  });
}
