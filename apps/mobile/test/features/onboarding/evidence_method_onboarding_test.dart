import 'package:archiveme_mobile/features/onboarding/evidence_method_onboarding_copy.dart';
import 'package:archiveme_mobile/features/onboarding/evidence_method_onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Evidence Method onboarding renders and Continue advances', (
    tester,
  ) async {
    var advanced = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidenceMethodOnboardingScreen(
            onContinue: () => advanced = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('evidence_method_onboarding_screen')), findsOneWidget);
    expect(find.text(EvidenceMethodOnboardingCopy.title), findsOneWidget);
    expect(find.text(EvidenceMethodOnboardingCopy.bullet1), findsOneWidget);

    await tester.tap(find.byKey(const Key('evidence_method_onboarding_continue')));
    await tester.pump();

    expect(advanced, isTrue);
  });
}
