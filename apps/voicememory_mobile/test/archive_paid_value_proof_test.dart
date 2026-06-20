import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/revenuecat_archive_loop_billing.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_return_value_proof.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_thought_map.dart';
import 'package:voicememory_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:voicememory_mobile/features/paywall/archive_paid_value_proof.dart';
import 'package:voicememory_mobile/screens/archive_loop_paywall_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/paywall/archive_paid_value_proof_panel.dart';

ArchiveThoughtMap _fullMap() {
  return const ArchiveThoughtMap(
    title: 'How the checking loop works',
    triggerNode: ArchiveThoughtMapNode(label: 'Trigger', text: 'Needs to work'),
    thoughtNode: ArchiveThoughtMapNode(
      label: 'Thought',
      text: 'I need to verify again',
    ),
    behaviourNode: ArchiveThoughtMapNode(
      label: 'Behaviour',
      text: 'I check again',
    ),
    reliefNode: ArchiveThoughtMapNode(label: 'Relief', text: 'Brief calm'),
    costNode: ArchiveThoughtMapNode(label: 'Cost', text: 'Time lost'),
    alternativeNode: ArchiveThoughtMapNode(
      label: 'Alternative',
      text: 'One check may be enough',
    ),
    nextTestNode: ArchiveThoughtMapNode(
      label: 'Next test',
      text: 'Watch whether one check is enough',
    ),
    strongestQuote: 'I keep checking again and again',
    supportQuote: 'I need this to work',
    confidenceLabel: 'Grounded in 2–3 entries',
    hasEnoughEvidence: true,
    mapConfidenceStatus: 'Grounded in 2–3 entries',
  );
}

ArchiveReturnValueProofResult _result(
  ArchiveReturnValueProofResultType type,
) {
  return ArchiveReturnValueProofResultResolver.resolve(
    ArchiveReturnValueProofInput(
      proof: ArchiveReturnValueProof(
        id: 'arvp_test',
        mapId: 'thought-map',
        sourceEntryId: 'entry-1',
        testQuestion: 'Watch whether one check is enough',
        testReason: 'Your behaviour step suggests checking may be doing more.',
        expectedSignal: 'Look for whether the urge to check comes back.',
        createdAt: DateTime.utc(2026, 6, 15, 12),
        dueLabel: 'Tomorrow',
      ),
      returnTranscript: switch (type) {
        ArchiveReturnValueProofResultType.repeated =>
          'I had to check again because the urge to check came back.',
        ArchiveReturnValueProofResultType.softened =>
          'The urge to check came back, but it felt less urgent and easier to stop.',
        ArchiveReturnValueProofResultType.shifted =>
          'Something new came up about money instead of the reassurance loop.',
        ArchiveReturnValueProofResultType.didNotReturn =>
          'It did not happen today. I forgot all about it.',
        ArchiveReturnValueProofResultType.unclear => 'I recorded a moment.',
      },
      sourceTranscript: 'I keep checking again and again.',
    ),
  );
}

List<String> _captureLogs(void Function() body) {
  final logs = <String>[];
  final previous = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  try {
    body();
  } finally {
    debugPrint = previous;
  }
  return logs;
}

void _useTallPaywallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ArchivePaidValueProof _proofFor({
  ArchiveThoughtMap? map,
  ArchiveReturnValueProofResult? result,
  int entryCount = 3,
}) {
  return ArchivePaidValueProofResolver.resolve(
    ArchivePaidValueProofInput(
      thoughtMap: map,
      latestReturnResult: result,
      entryCount: entryCount,
      now: DateTime.utc(2026, 6, 15, 12),
    ),
  );
}

void main() {
  group('ArchivePaidValueProofResolver', () {
    test('first full map generates Your first loop is mapped', () {
      final proof = _proofFor(map: _fullMap());
      expect(proof.title, 'Your first loop is mapped');
      expect(proof.source, ArchivePaidValueProofSource.firstMap);
      expect(proof.evidenceLine, contains('strongest clue'));
      expect(
        ArchivePaidValueProofResolver.paywallHeadline(proof),
        'Keep your loop map alive',
      );
    });

    test('repeated return result generates This loop came back', () {
      final proof = _proofFor(
        map: _fullMap(),
        result: _result(ArchiveReturnValueProofResultType.repeated),
      );
      expect(proof.title, 'This loop came back');
      expect(proof.source, ArchivePaidValueProofSource.repeatedLoop);
      expect(proof.valueLine, contains('keeps tracking'));
      expect(
        ArchivePaidValueProofResolver.paywallHeadline(proof),
        'Keep testing what changed',
      );
    });

    test('softened return result generates This loop changed', () {
      final proof = _proofFor(
        map: _fullMap(),
        result: _result(ArchiveReturnValueProofResultType.softened),
      );
      expect(proof.title, 'This loop changed');
      expect(proof.source, ArchivePaidValueProofSource.softenedLoop);
      expect(proof.valueLine, contains('softening lasts'));
    });

    test('shifted return result generates The loop changed shape', () {
      final proof = _proofFor(
        map: _fullMap(),
        result: _result(ArchiveReturnValueProofResultType.shifted),
      );
      expect(proof.title, 'The loop changed shape');
      expect(proof.source, ArchivePaidValueProofSource.shiftedLoop);
      expect(proof.valueLine, contains('moves next'));
    });

    test('fallback avoids generic premium wording', () {
      final proof = _proofFor();
      expect(proof.source, ArchivePaidValueProofSource.genericFallback);
      expect(proof.title, 'Keep testing your loop');
      final blob = [
        proof.title,
        proof.valueLine,
        proof.riskLine,
        proof.primaryBullet,
        proof.secondaryBullet,
        proof.tertiaryBullet,
      ].join(' ').toLowerCase();
      expect(blob, isNot(contains('unlock unlimited')));
      expect(blob, isNot(contains('premium insights')));
      expect(blob, isNot(contains('ai coach')));
    });

    test('no therapy or diagnostic language', () {
      const banned = [
        'diagnosis',
        'diagnose',
        'therapy',
        'therapist',
        'guaranteed improvement',
      ];
      final proofs = [
        _proofFor(map: _fullMap()),
        _proofFor(
          map: _fullMap(),
          result: _result(ArchiveReturnValueProofResultType.repeated),
        ),
        _proofFor(
          map: _fullMap(),
          result: _result(ArchiveReturnValueProofResultType.softened),
        ),
        _proofFor(),
      ];
      for (final proof in proofs) {
        final blob = [
          proof.title,
          proof.evidenceLine,
          proof.valueLine,
          proof.riskLine,
          proof.proPromiseLine,
          proof.primaryBullet,
          proof.secondaryBullet,
          proof.tertiaryBullet,
        ].join(' ').toLowerCase();
        for (final word in banned) {
          expect(blob, isNot(contains(word)), reason: '${proof.source} $word');
        }
      }
    });

    test('bullets are concrete and not unlock unlimited', () {
      final proof = _proofFor(map: _fullMap());
      expect(proof.primaryBullet, 'Save future loop tests');
      expect(proof.secondaryBullet, 'Track whether this comes back');
      expect(proof.tertiaryBullet, 'See how the map changes over time');
      expect(proof.primaryBullet.toLowerCase(), isNot(contains('unlock')));
    });

    test('logs use approved copy hygiene', () {
      final logs = _captureLogs(() {
        ArchivePaidValueProofResolver.resolve(
          ArchivePaidValueProofInput(
            thoughtMap: _fullMap(),
            now: DateTime.utc(2026, 6, 15, 12),
          ),
        );
        ArchivePaidValueProofLog.shown(surface: 'post_activation');
        ArchivePaidValueProofLog.ctaTapped(source: 'firstMap');
      });
      expect(
        logs.any(
          (line) => line.contains('ARCHIVEME_PAID_VALUE_PROOF_RESOLVED'),
        ),
        isTrue,
      );
      expect(
        logs.any((line) => line.contains('ARCHIVEME_PAID_VALUE_PROOF_SHOWN')),
        isTrue,
      );
      expect(
        logs.any(
          (line) => line.contains('ARCHIVEME_PAID_VALUE_PROOF_CTA_TAPPED'),
        ),
        isTrue,
      );
      for (final line in logs) {
        expect(line, isNot(contains('{{')));
        expect(line, isNot(contains('null')));
      }
    });
  });

  group('ArchiveLoopPaywallCopy feature gates', () {
    test('uses evidence-based gate lines', () {
      expect(
        ArchiveLoopPaywallCopy.featureGateLine(
          ArchiveLoopEntitlementFeature.edit,
        ),
        contains('first loop map is free'),
      );
      expect(
        ArchiveLoopPaywallCopy.featureGateLine(
          ArchiveLoopEntitlementFeature.returnCheck,
        ),
        contains('comes back or changes'),
      );
      expect(
        ArchiveLoopPaywallCopy.featureGateLine(
          ArchiveLoopEntitlementFeature.evidence,
        ),
        contains('evidence trail'),
      );
    });
  });

  group('ArchivePaidValueProofPanel', () {
    testWidgets('renders Why Pro now', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchivePaidValueProofPanel(
              proof: _proofFor(map: _fullMap()),
              surface: 'test',
            ),
          ),
        ),
      );

      expect(find.text('Why Pro now'), findsOneWidget);
      expect(find.text('Your first loop is mapped'), findsOneWidget);
      expect(find.text('Save future loop tests'), findsOneWidget);
    });
  });

  group('ArchiveLoopPaywallScreen paid value proof', () {
    testWidgets('subscription metadata and purchase controls remain visible', (
      tester,
    ) async {
      _useTallPaywallViewport(tester);
      final billing = FakeRevenueCatArchiveLoopBilling(
        configured: true,
        priceLine: r'$6.99 / month',
        entitlementStore: () async => null,
      );
      final proof = _proofFor(
        map: _fullMap(),
        result: _result(ArchiveReturnValueProofResultType.repeated),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveLoopPaywallScreen(
            billing: billing,
            initialProof: proof,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Keep testing what changed'),
        findsOneWidget,
      );
      expect(find.text('Why Pro now'), findsOneWidget);
      expect(find.text('This loop came back'), findsOneWidget);
      expect(
        find.byKey(const Key('archive_loop_paywall_subscription_details')),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveLoopPaywallCopy.subscriptionDetailsTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_loop_paywall_start_pro')),
        findsOneWidget,
      );
      expect(find.text('Keep testing this loop'), findsWidgets);
      expect(
        find.byKey(const Key('archive_loop_paywall_restore')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_loop_paywall_not_now')),
        findsOneWidget,
      );
    });
  });
}
