import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/coaching/controllers/coaching_state_controller.dart';
import 'package:voicememory_mobile/features/coaching/services/coaching_engine_service.dart';
import 'package:voicememory_mobile/features/coaching/widgets/coaching_insight_card.dart';
import 'package:voicememory_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('renders coaching content and confidence', (tester) async {
    final insight = CoachingInsight(
      id: 'daily:test',
      category: 'Daily Summary',
      content: 'Planning appeared repeatedly today.',
      confidenceScore: 0.76,
      generatedAt: DateTime.utc(2026, 7, 29),
      sourceEntryIds: const ['one', 'two'],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CoachingInsightCard(state: CoachingState(insight: insight)),
        ),
      ),
    );

    expect(find.byKey(const Key('archive_coaching_insight_card')), findsOne);
    expect(find.text('Daily Summary'), findsOne);
    expect(find.text('Planning appeared repeatedly today.'), findsOne);
    expect(find.text('76% confidence'), findsOne);
    final semanticsWidget = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.startsWith('Daily Summary.') == true,
      ),
    );
    expect(
      semanticsWidget.properties.hint,
      'AI-generated reflection based on recent journal evidence.',
    );
  });
}
