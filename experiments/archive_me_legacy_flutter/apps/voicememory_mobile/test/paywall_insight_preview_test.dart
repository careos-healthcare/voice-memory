import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/widgets/paywall/paywall_insight_preview.dart';

void main() {
  testWidgets('sample analyst and evolution output expands interactively', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PaywallInsightPreview()),
        ),
      ),
    );

    expect(
      tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .crossFadeState,
      CrossFadeState.showFirst,
    );

    await tester.tap(find.byKey(const Key('paywall_insight_preview_toggle')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .crossFadeState,
      CrossFadeState.showSecond,
    );
    expect(
      find.byKey(const Key('paywall_archive_analyst_sample')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('paywall_evolution_timeline_sample')),
      findsOneWidget,
    );
    expect(
      find.text('I take responsibility before asking for help.'),
      findsWidgets,
    );
    expect(find.textContaining('Archive Audio Digest'), findsOneWidget);
    expect(find.text('Sample output · fictional moments'), findsOneWidget);
  });

  testWidgets('PaywallScreen places the demo before payment controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PaywallScreen(
          billingReadyOverride: () => false,
          delayedPaywallProofGateOverride: () => true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PaywallInsightPreview), findsOneWidget);
    expect(
      find.byKey(const Key('paywall_insight_preview_toggle')),
      findsOneWidget,
    );
  });
}
