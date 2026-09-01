import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const claim = 'Work pressure keeps showing up before you agree.';

  Future<void> pumpLink(
    WidgetTester tester, {
    String? claimContext,
    VoidCallback? onViewEvidence,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ViewEvidenceInlineLink(
            key: const Key('view_evidence_under_test'),
            entryIds: const ['e1'],
            surface: 'test',
            claimContext: claimContext,
            onViewEvidence: onViewEvidence ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('keeps a 48pt minimum tap target', (tester) async {
    await pumpLink(tester, claimContext: claim);

    final size = tester.getSize(find.byKey(const Key('view_evidence_under_test')));
    expect(size.height, greaterThanOrEqualTo(ViewEvidenceInlineLink.minTapTarget));
  });

  testWidgets('screen-reader label includes the adjacent claim', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLink(tester, claimContext: claim);

    expect(
      tester.getSemantics(find.byKey(const Key('view_evidence_under_test'))),
      matchesSemantics(
        label: '${VisibleArchiveProofCopy.beliefUpdateViewEvidenceCta}. $claim',
        isButton: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('falls back to the visible CTA when no claim is provided', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpLink(tester);

    expect(
      tester.getSemantics(find.byKey(const Key('view_evidence_under_test'))),
      matchesSemantics(
        label: VisibleArchiveProofCopy.beliefUpdateViewEvidenceCta,
        isButton: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('tap still opens evidence via the override', (tester) async {
    var opened = false;
    await pumpLink(tester, claimContext: claim, onViewEvidence: () {
      opened = true;
    });

    await tester.tap(find.byKey(const Key('view_evidence_under_test')));
    await tester.pump();
    expect(opened, isTrue);
  });
}
