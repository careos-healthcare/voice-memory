import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_tab/archive_tab_four_state_copy.dart';
import 'package:voicememory_mobile/features/archive_tab/archive_tab_four_state_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/archive/archive_tab_entry_state_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

void main() {
  group('ArchiveTabFourStateEngine', () {
    test('state 1 empty archive copy and record CTA', () {
      final model = ArchiveTabFourStateEngine.build(entries: const [])!;

      expect(model.state, ArchiveTabFourState.empty);
      expect(model.body, ArchiveTabFourStateCopy.emptyBody);
      expect(model.primaryCta, ArchiveTabFourStateCopy.recordMomentCta);
    });

    test('state 2 one entry has no primary CTA', () {
      final model = ArchiveTabFourStateEngine.build(
        entries: [
          _entry(
            id: 'a',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
          ),
        ],
      )!;

      expect(model.state, ArchiveTabFourState.one);
      expect(model.body, ArchiveTabFourStateCopy.oneBody);
      expect(model.showPrimaryCta, isFalse);
    });

    test('state 3 two unrelated entries does not claim a pattern', () {
      final model = ArchiveTabFourStateEngine.build(
        entries: [
          _entry(
            id: 'a',
            transcript: 'A calm afternoon walk helped me slow down before dinner.',
            createdAt: DateTime(2026, 6, 10, 12),
          ),
          _entry(
            id: 'b',
            transcript: 'I reorganized my bookshelf and found an old notebook.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
        ],
      )!;

      expect(model.state, ArchiveTabFourState.twoUnrelated);
      expect(model.body, ArchiveTabFourStateCopy.twoUnrelatedBody);
      expect(model.showPrimaryCta, isFalse);
    });

    test('state 4 two related entries includes thread, change, and view evidence', () {
      final model = ArchiveTabFourStateEngine.build(
        entries: [
          _entry(
            id: 'a',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
            createdAt: DateTime(2026, 6, 10, 12),
          ),
          _entry(
            id: 'b',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
        ],
      )!;

      expect(model.state, ArchiveTabFourState.twoRelated);
      expect(model.body, startsWith(ArchiveTabFourStateCopy.twoRelatedLead));
      expect(model.body, contains("This may connect to:"));
      expect(model.body, contains('What changed:'));
      expect(model.primaryCta, ArchiveTabFourStateCopy.viewEvidenceCta);
      expect(model.primaryAction.name, 'viewEvidence');
    });
  });

  group('ArchiveTabEntryStateCard', () {
    testWidgets('empty state shows record moment button only', (tester) async {
      final model = ArchiveTabFourStateEngine.build(entries: const [])!;
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveTabEntryStateCard(
              model: model,
              onPrimary: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(ArchiveTabFourStateCopy.emptyBody), findsOneWidget);
      expect(find.text('Record a moment'), findsOneWidget);
      expect(find.text('Patterns'), findsNothing);
      expect(find.text('Changes'), findsNothing);
      expect(find.text('Type instead'), findsNothing);

      await tester.tap(find.text('Record a moment'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
