import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/ui/ai_feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PremiumAccess.apply(PremiumEntitlement.free));

  testWidgets('free tier opens the paywall and keeps playback open', (
    tester,
  ) async {
    var played = false;
    var drafted = false;
    var coached = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monetizationRevenueCatServiceProvider.overrideWithValue(
            MonetizationRevenueCatService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AIFeatureGate(
              transcript: 'The rent is due tomorrow.',
              onPlay: () => played = true,
              onEmailDraft: () => drafted = true,
              onAdvancedCoaching: () => coached = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('The rent is due tomorrow.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_gate_play')));
    await tester.pump();
    expect(played, isTrue);
    expect(find.text('Start Premium'), findsNothing);

    await tester.tap(find.byKey(const Key('ai_gate_email')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(drafted, isFalse);
    expect(find.text('Start Premium'), findsNothing);
    expect(find.text('The rent is due tomorrow.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai_gate_coaching')));
    await tester.pump();
    expect(coached, isFalse);
    expect(find.text('Start Premium'), findsNothing);
  });

  testWidgets('an active entitlement runs advanced rewrites', (tester) async {
    var drafted = false;
    var coached = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monetizationRevenueCatServiceProvider.overrideWithValue(
            MonetizationRevenueCatService(seed: PremiumEntitlement.active),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AIFeatureGate(
              transcript: 'The rent is due tomorrow.',
              onEmailDraft: () => drafted = true,
              onAdvancedCoaching: () => coached = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_gate_email')));
    await tester.tap(find.byKey(const Key('ai_gate_coaching')));
    await tester.pump();
    expect(drafted, isTrue);
    expect(coached, isTrue);
    expect(find.text('Start Premium'), findsNothing);
    expect(find.text('The rent is due tomorrow.'), findsOneWidget);
  });
}
