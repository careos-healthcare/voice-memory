import 'package:archiveme_mobile/features/monetization/output_format_gate.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PremiumAccess.apply(PremiumEntitlement.free));

  test('free formats stay open and premium formats follow the entitlement', () {
    expect(OutputFormatGate.isFree(FreeOutputFormat.transcription), isTrue);
    expect(OutputFormatGate.isFree(FreeOutputFormat.playback), isTrue);
    for (final format in PremiumOutputFormat.values) {
      expect(OutputFormatGate.allows(format, PremiumEntitlement.free), isFalse);
      expect(
        OutputFormatGate.allows(format, PremiumEntitlement.active),
        isTrue,
      );
    }
  });

  testWidgets('free tier keeps playback until a milestone is completed', (
    tester,
  ) async {
    var played = false;
    var drafted = false;
    var templated = false;
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
            body: OutputFormatSurface(
              transcript: 'The rent is due tomorrow.',
              onPlay: () => played = true,
              onEmailDraft: () => drafted = true,
              onProfessionalTemplate: () => templated = true,
              onCoachingInsights: () => coached = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('The rent is due tomorrow.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('output_gate_play')));
    await tester.pump();
    expect(played, isTrue);
    expect(find.text('Start Premium'), findsNothing);

    Future<void> expectStillClosed(Key key) async {
      await tester.tap(find.byKey(key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Start Premium'), findsNothing);
    }

    await expectStillClosed(const Key('output_gate_email'));
    await expectStillClosed(const Key('output_gate_template'));
    await expectStillClosed(const Key('output_gate_coaching'));
    expect(drafted, isFalse);
    expect(templated, isFalse);
    expect(coached, isFalse);
  });

  testWidgets('an active entitlement runs every premium format', (
    tester,
  ) async {
    var drafted = false;
    var templated = false;
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
            body: OutputFormatSurface(
              transcript: 'The rent is due tomorrow.',
              onEmailDraft: () => drafted = true,
              onProfessionalTemplate: () => templated = true,
              onCoachingInsights: () => coached = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('output_gate_email')));
    await tester.tap(find.byKey(const Key('output_gate_template')));
    await tester.tap(find.byKey(const Key('output_gate_coaching')));
    await tester.pump();
    expect(drafted, isTrue);
    expect(templated, isTrue);
    expect(coached, isTrue);
    expect(find.text('Start Premium'), findsNothing);
    expect(find.text('The rent is due tomorrow.'), findsOneWidget);
  });
}
