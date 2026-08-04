import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/pattern_evidence_view_state.dart';
import 'package:voicememory_mobile/features/comparison_engine/presentation/widgets/pattern_evidence_card.dart';
import 'package:voicememory_mobile/features/pro_conversion_audit/pro_conversion_audit_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  group('PatternEvidenceCard', () {
    testWidgets('renders comparison evidence without pro prompt by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternEvidenceCard(
              viewState: const PatternEvidenceViewState(
                state: PatternState.possibleRepeat,
                connectionText: 'This may connect to saying yes again.',
                pastQuote: 'said yes before checking',
                currentQuote: 'said yes again at work',
                whatChangedText: 'It showed up around work again.',
                showProTrailPrompt: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Archive Comparison'), findsOneWidget);
      expect(find.text('Possible Repeat'), findsOneWidget);
      expect(
        find.byKey(const Key('pattern_evidence_pro_trail_prompt')),
        findsNothing,
      );
    });

    testWidgets(
      'shows growth microcopy for softened changed and corrected labels',
      (tester) async {
        for (final state in [
          PatternState.softened,
          PatternState.changed,
          PatternState.corrected,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: PatternEvidenceCard(
                  viewState: PatternEvidenceViewState(
                    state: state,
                    connectionText:
                        'This connects to noticing pressure sooner.',
                    pastQuote: 'I only noticed after I had already said yes.',
                    currentQuote: 'I noticed the pressure before I answered.',
                    whatChangedText: 'The cue was noticed earlier.',
                    showProTrailPrompt: false,
                  ),
                ),
              ),
            ),
          );

          expect(
            find.text(PatternEvidenceCard.changedPatternHighlight),
            findsOneWidget,
            reason: 'Expected growth highlight for ${state.name}',
          );
        }
      },
    );

    testWidgets('visibly contrasts past and present verbatim quotes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternEvidenceCard(
              viewState: const PatternEvidenceViewState(
                state: PatternState.changed,
                connectionText: 'This connects to noticing pressure sooner.',
                pastQuote: 'I only noticed after I had already said yes.',
                currentQuote: 'I noticed the pressure before I answered.',
                whatChangedText: 'The cue was noticed earlier.',
                showProTrailPrompt: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('PAST — YOUR WORDS'), findsOneWidget);
      expect(find.text('PRESENT — YOUR WORDS'), findsOneWidget);
      expect(
        find.text('"I only noticed after I had already said yes."'),
        findsOneWidget,
      );
      expect(
        find.text('"I noticed the pressure before I answered."'),
        findsOneWidget,
      );

      final past = tester.widget<Container>(
        find.byKey(const Key('pattern_evidence_past_quote')),
      );
      final present = tester.widget<Container>(
        find.byKey(const Key('pattern_evidence_present_quote')),
      );
      final pastDecoration = past.decoration! as BoxDecoration;
      final presentDecoration = present.decoration! as BoxDecoration;
      expect(pastDecoration.color, isNot(presentDecoration.color));
      expect(pastDecoration.border, isNot(presentDecoration.border));
    });

    testWidgets('renders conversion headline when pro prompt is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternEvidenceCard(
              viewState: PatternEvidenceViewState(
                state: PatternState.clearRepeat,
                connectionText: 'This may connect to saying yes again.',
                pastQuote: 'said yes before checking',
                currentQuote: 'said yes again at work',
                whatChangedText: 'It showed up around work again.',
                showProTrailPrompt: true,
                conversionHeadline: ProConversionAuditCopy.proTrailCanonical,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('pattern_evidence_pro_trail_prompt')),
        findsOneWidget,
      );
      expect(
        find.text(ProConversionAuditCopy.proTrailCanonical),
        findsOneWidget,
      );
    });

    testWidgets('invokes paywall callback when conversion headline is tapped', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternEvidenceCard(
              viewState: PatternEvidenceViewState(
                state: PatternState.clearRepeat,
                connectionText: 'This may connect to saying yes again.',
                pastQuote: 'said yes before checking',
                currentQuote: 'said yes again at work',
                whatChangedText: 'It showed up around work again.',
                showProTrailPrompt: true,
                conversionHeadline: ProConversionAuditCopy.proTrailCanonical,
              ),
              onProUpgradeTapped: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('pattern_evidence_pro_trail_prompt')),
      );
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
