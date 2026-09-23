import 'package:archiveme_mobile/features/playback/local_ai_coach.dart';
import 'package:archiveme_mobile/widgets/record/local_ai_coaching_parameter_toggles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coaching switches stay hidden until three saved entries', () {
    expect(
      LocalAiCoachingParameterToggles.visibleForEntryCount(0),
      isFalse,
    );
    expect(
      LocalAiCoachingParameterToggles.visibleForEntryCount(2),
      isFalse,
    );
    expect(LocalAiCoachingParameterToggles.visibleForEntryCount(3), isTrue);
  });

  testWidgets('entry form shows only core fields before three saves', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocalAiCoachingParameterToggles(
            successfulEntryCount: 2,
            parameters: LocalAiCoachingParameters(),
            onChanged: _ignore,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('local_ai_coaching_parameters')), findsNothing);
    expect(find.text('Notice pauses'), findsNothing);
  });

  testWidgets('entry form reveals coaching switches after three saves', (
    tester,
  ) async {
    var saved = const LocalAiCoachingParameters();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return LocalAiCoachingParameterToggles(
                successfulEntryCount: 3,
                parameters: saved,
                onChanged: (next) => setState(() => saved = next),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Notice pauses'), findsOneWidget);
    expect(find.text('Keep quiet stretches'), findsOneWidget);
    expect(find.text('Write a short note'), findsOneWidget);

    await tester.tap(find.byKey(const Key('local_ai_coaching_notice_pauses')));
    await tester.pump();

    expect(saved.noticePauses, isFalse);
  });
}

void _ignore(LocalAiCoachingParameters _) {}
