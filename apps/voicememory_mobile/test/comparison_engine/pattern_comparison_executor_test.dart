import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/pattern_comparison_executor.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/pro_trail_gate.dart';
import 'package:voicememory_mobile/features/pro_conversion_audit/pro_conversion_audit_copy.dart';

ArchiveMomentRecord _moment({
  required String id,
  required String words,
  PatternState alignmentState = PatternState.earlySignal,
  DateTime? createdAt,
}) => ArchiveMomentRecord(
  id: id,
  createdAt: createdAt ?? DateTime.utc(2026, 6, 10),
  savedWords: words,
  alignmentState: alignmentState,
);

const _sampleModelOutput = '''
---
Label: Clear repeat
Connection: This may connect to saying yes before checking capacity.
Evidence:
- Past: "I said yes again before I checked my calendar."
- Present: "I said yes at work without thinking."
What Changed: The repeat showed up around work again with similar wording.
---
''';

void main() {
  const executor = PatternComparisonExecutor();

  group('PatternComparisonExecutor', () {
    test('buildComparisonPlan limits historical context for free users', () {
      final current = _moment(
        id: 'current',
        words: 'said yes again at work',
        alignmentState: PatternState.clearRepeat,
      );
      final history = [
        _moment(id: '1', words: 'first yes'),
        _moment(id: '2', words: 'second yes'),
      ];

      final plan = executor.buildComparisonPlan(
        currentMoment: current,
        historicalMoments: history,
        isPro: false,
        hasDismissedProTrailPrompt: false,
      );

      expect(plan.visibleHistoricalMoments.length, 1);
      expect(plan.visibleHistoricalMoments.single.id, '2');
      expect(plan.userPrompt, contains('second yes'));
      expect(plan.userPrompt, isNot(contains('first yes')));
    });

    test('buildComparisonPlan keeps full history for pro users', () {
      final plan = executor.buildComparisonPlan(
        currentMoment: _moment(
          id: 'current',
          words: 'said yes again at work',
          alignmentState: PatternState.clearRepeat,
        ),
        historicalMoments: [
          _moment(id: '1', words: 'first yes'),
          _moment(id: '2', words: 'second yes'),
        ],
        isPro: true,
        hasDismissedProTrailPrompt: false,
      );

      expect(plan.visibleHistoricalMoments.length, 2);
      expect(plan.isPro, isTrue);
    });

    test(
      'buildComparisonPlan prunes oversized pro history before prompt build',
      () {
        const prunedExecutor = PatternComparisonExecutor(
          maxHistoricalContextItems: 30,
        );
        final history = [
          for (var day = 1; day <= 35; day++)
            ArchiveMomentRecord(
              id: 'm$day',
              createdAt: DateTime.utc(2026, 1, day),
              savedWords: 'moment $day',
            ),
        ];

        final plan = prunedExecutor.buildComparisonPlan(
          currentMoment: _moment(
            id: 'current',
            words: 'latest moment',
            alignmentState: PatternState.possibleRepeat,
          ),
          historicalMoments: history,
          isPro: true,
          hasDismissedProTrailPrompt: false,
        );

        expect(plan.visibleHistoricalMoments.length, 30);
        expect(plan.visibleHistoricalMoments.first.id, 'm6');
        expect(plan.visibleHistoricalMoments.last.id, 'm35');
        expect(plan.totalMomentCount, 36);
        expect(plan.userPrompt, contains('moment 6'));
        expect(plan.userPrompt, isNot(contains('moment 5')));
      },
    );

    test(
      'buildEvidenceViewState uses parsed PatternState for ProTrailGate',
      () {
        final plan = executor.buildComparisonPlan(
          currentMoment: _moment(
            id: 'current',
            words: 'I said yes at work without thinking.',
            alignmentState: PatternState.earlySignal,
            createdAt: DateTime.utc(2026, 7, 10),
          ),
          historicalMoments: [
            _moment(
              id: '1',
              words: 'I said yes again before I checked my calendar.',
            ),
          ],
          isPro: false,
          hasDismissedProTrailPrompt: false,
        );
        final parsed = executor.parseModelOutput(_sampleModelOutput);

        final viewState = executor.buildEvidenceViewStateFromRawOutput(
          plan: plan,
          rawModelOutput: _sampleModelOutput,
        );

        expect(parsed.state, PatternState.clearRepeat);
        expect(viewState.state, PatternState.clearRepeat);
        expect(viewState.showProTrailPrompt, isTrue);
        expect(viewState.conversionHeadline, ProTrailGate.conversionHeadline);
        expect(
          viewState.connectionText,
          'This may connect to saying yes before checking capacity.',
        );
        expect(
          viewState.pastQuote,
          'I said yes again before I checked my calendar.',
        );
        expect(viewState.currentQuote, 'I said yes at work without thinking.');
      },
    );

    test('buildEvidenceViewStateFromRawOutput runs full integration flow', () {
      final plan = executor.buildComparisonPlan(
        currentMoment: _moment(
          id: 'current',
          words: 'I said yes at work without thinking.',
          alignmentState: PatternState.earlySignal,
          createdAt: DateTime.utc(2026, 7, 10),
        ),
        historicalMoments: [
          _moment(
            id: '1',
            words: 'I said yes again before I checked my calendar.',
          ),
        ],
        isPro: false,
        hasDismissedProTrailPrompt: false,
      );

      final viewState = executor.buildEvidenceViewStateFromRawOutput(
        plan: plan,
        rawModelOutput: _sampleModelOutput,
      );

      expect(viewState.state, PatternState.clearRepeat);
      expect(viewState.showProTrailPrompt, isTrue);
      expect(
        viewState.conversionHeadline,
        ProConversionAuditCopy.proTrailCanonical,
      );
    });

    test(
      'parsed notEnoughEvidence suppresses pro prompt even with enough moments',
      () {
        final plan = executor.buildComparisonPlan(
          currentMoment: _moment(
            id: 'current',
            words: 'unrelated note',
            alignmentState: PatternState.possibleRepeat,
          ),
          historicalMoments: [_moment(id: '1', words: 'first yes')],
          isPro: false,
          hasDismissedProTrailPrompt: false,
        );

        final viewState = executor.buildEvidenceViewStateFromRawOutput(
          plan: plan,
          rawModelOutput: 'Label: Not enough evidence',
        );

        expect(viewState.state, PatternState.notEnoughEvidence);
        expect(viewState.showProTrailPrompt, isFalse);
        expect(viewState.conversionHeadline, isNull);
      },
    );
  });
}
