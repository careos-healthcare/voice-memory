import 'package:archiveme_mobile/features/pressure_retention/pressure_context.dart';
import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:archiveme_mobile/features/trust/aha_proof_share_eligibility.dart';
import 'package:archiveme_mobile/features/trust/pro_trust_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/evidence_context_tag_card.dart';
import 'package:archiveme_mobile/widgets/share/aha_proof_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _narrowScreen = Size(320, 640);

Future<void> _pumpNarrowCard(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(_narrowScreen);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          key: const Key('record_screen_scroll'),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('EvidenceContextTagCard layout', () {
    testWidgets('renders at 320px without infinite width constraints', (
      tester,
    ) async {
      await _pumpNarrowCard(
        tester,
        EvidenceContextTagCard(onSaveTag: (_) {}, onSkip: () {}),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('evidence_context_tag_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('evidence_context_tag_save')),
        findsOneWidget,
      );
    });

    testWidgets('save button is tappable after selecting a tag', (
      tester,
    ) async {
      PressureContext? saved;
      await _pumpNarrowCard(
        tester,
        EvidenceContextTagCard(onSaveTag: (tag) => saved = tag, onSkip: () {}),
      );

      await tester.tap(find.byKey(const Key('evidence_context_tag_work')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('evidence_context_tag_save')));
      await tester.pump();

      expect(saved, PressureContext.work);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'post-save stack keeps share buttons hittable after context tag',
      (tester) async {
        AhaProofShareEligibility.markEligibleFromAhaUseful();
        var copied = false;

        await _pumpNarrowCard(
          tester,
          Column(
            children: [
              EvidenceContextTagCard(onSaveTag: (_) {}, onSkip: () {}),
              AhaProofShareCard(
                entryCount: 2,
                onDismiss: () {},
                onCopy: (_) async => copied = true,
                onShare: (_) async {},
              ),
            ],
          ),
        );

        await tester.tap(find.byKey(const Key('evidence_context_tag_health')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('evidence_context_tag_save')));
        await tester.pump();

        final scroll = find.byKey(const Key('record_screen_scroll'));
        await tester.drag(scroll, const Offset(0, -400));
        await tester.pumpAndSettle();

        final copyButton = find.byKey(const Key('aha_proof_share_copy'));
        await tester.ensureVisible(copyButton);
        await tester.tap(copyButton);
        await tester.pump();

        expect(copied, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    test('save label and share copy remain ArchiveMe-branded', () {
      expect(ProTrustCopy.shareTextTemplate, contains('ArchiveMe'));
      expect(ProTrustCopy.shareCopyCta, isNotEmpty);
      expect(ArchiveShareActions.copyConfirmation, 'Share text copied');
    });
  });
}