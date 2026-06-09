import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_map_card.dart';

PatternMap _map({String? nextCheck = 'What happens right before it shows up?'}) =>
    PatternMap(
      patternTitle: 'Taking responsibility before asking for help',
      seenCount: 4,
      lastSeenDate: DateTime(2026, 6, 4),
      usuallyStartsBefore: 'before saying yes',
      oftenFeelsLike: 'heavier',
      getsLighterWhen: 'paused before answering',
      getsHeavierWhen: 'took it on alone',
      nextCheck: nextCheck,
      confidenceLabel: 'Based on 4 check-ins',
    );

Future<void> _pump(WidgetTester tester, PatternMap map,
    {void Function(String)? onUseCheck}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PatternMapCard(map: map, onUseCheck: onUseCheck),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders all the sections', (tester) async {
    await _pump(tester, _map());
    expect(find.text('Seen'), findsOneWidget);
    expect(find.text('Usually starts'), findsOneWidget);
    expect(find.text('Often feels'), findsOneWidget);
    expect(find.text('Gets lighter when'), findsOneWidget);
    expect(find.text('Gets heavier when'), findsOneWidget);
    expect(find.text('Next check'), findsOneWidget);
    expect(find.textContaining('4 times'), findsOneWidget);
    expect(find.text('paused before answering'), findsOneWidget);
  });

  testWidgets('renders memory quality chip instead of confidence label',
      (tester) async {
    await _pump(tester, _map());
    expect(find.text('Getting clearer'), findsOneWidget);
    expect(find.text('Based on 4 check-ins'), findsNothing);
  });

  testWidgets('Use this check fires with the next check', (tester) async {
    String? used;
    await _pump(tester, _map(), onUseCheck: (q) => used = q);
    await tester.tap(find.text('Use this check'));
    await tester.pump();
    expect(used, 'What happens right before it shows up?');
  });

  testWidgets('hides empty sections and the CTA without a next check',
      (tester) async {
    await _pump(
      tester,
      _map(nextCheck: null).copyWith(getsLighterWhen: ''),
    );
    expect(find.text('Next check'), findsNothing);
    expect(find.text('Use this check'), findsNothing);
  });
}
