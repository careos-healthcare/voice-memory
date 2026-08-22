import 'dart:io';

import 'package:archiveme_mobile/features/archive_depth/archive_depth_copy.dart';
import 'package:archiveme_mobile/features/archive_depth/archive_depth_engine.dart';
import 'package:archiveme_mobile/features/archive_depth/archive_depth_gates.dart';
import 'package:archiveme_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:archiveme_mobile/features/pro_value/pro_value_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive_depth_card.dart';
import 'package:archiveme_research/screens/pro_value_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Start trial',
  'Limited time',
];

const _longTranscript =
    'Work pressure showed up again today and I noticed the same tight feeling.';

JournalEntry _entry(
  String id, {
  String? transcript,
  String? captureContextTag,
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: transcript ?? _longTranscript,
  durationSeconds: 30,
  localAudioPath: localAudioPath ?? '/tmp/$id.m4a',
  captureContextTag: captureContextTag,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _entries(int count) =>
    List.generate(count, (i) => _entry('e$i'));

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  const engine = ArchiveDepthEngine();

  group('Archive depth engine levels', () {
    test('0 entries returns Archive not started yet', () {
      final result = engine.build(entries: const []);
      expect(result.level, ArchiveDepthLevel.notStarted);
      expect(result.levelLabel, ArchiveDepthCopy.notStartedLabel);
    });

    test('1 entry returns First evidence saved', () {
      final result = engine.build(entries: [_entry('e1')]);
      expect(result.level, ArchiveDepthLevel.firstEvidence);
      expect(result.levelLabel, ArchiveDepthCopy.firstEvidenceLabel);
    });

    test('2 entries returns Starting to compare', () {
      final result = engine.build(entries: _entries(2));
      expect(result.level, ArchiveDepthLevel.startingToCompare);
      expect(result.levelLabel, ArchiveDepthCopy.startingToCompareLabel);
    });

    test('3–4 entries returns Cautious belief forming', () {
      for (final count in [3, 4]) {
        final result = engine.build(entries: _entries(count));
        expect(result.level, ArchiveDepthLevel.cautiousBelief);
        expect(result.levelLabel, ArchiveDepthCopy.cautiousBeliefLabel);
      }
    });

    test('5–9 entries returns Weekly review ready', () {
      for (final count in [5, 9]) {
        final result = engine.build(entries: _entries(count));
        expect(result.level, ArchiveDepthLevel.weeklyReviewReady);
        expect(result.levelLabel, ArchiveDepthCopy.weeklyReviewLabel);
      }
    });

    test('10+ entries returns Long-term archive building', () {
      final result = engine.build(entries: _entries(10));
      expect(result.level, ArchiveDepthLevel.longTermBuilding);
      expect(result.levelLabel, ArchiveDepthCopy.longTermLabel);
    });
  });

  group('Archive depth evidence counts', () {
    test('degraded and blank entries excluded from usable evidence count', () {
      final entries = [
        _entry('good1'),
        _entry('good2'),
        _entry('blank', transcript: ''),
        _entry('draft', transcript: '[draft] unfinished note'),
        _entry(
          'degraded',
          transcript: 'short',
          localAudioPath: '/tmp/degraded.m4a',
        ),
        _entry('short', transcript: 'too short for evidence'),
      ];
      final result = engine.build(entries: entries);
      expect(result.savedCount, 4);
      expect(result.usableEvidenceCount, 2);
      expect(
        result.progressLabel,
        '4 saved moments · 2 usable evidence moments',
      );
    });
  });

  group('Archive depth monetisation', () {
    test('Pro line appears only at 10+ entries', () {
      expect(engine.build(entries: _entries(9)).showProLine, isFalse);
      expect(engine.build(entries: _entries(10)).showProLine, isTrue);
    });
  });

  group('Archive depth copy', () {
    test('uses ArchiveMe and avoids banned language', () {
      _expectNoBannedCopy(ArchiveDepthCopy.allVisibleCopy());
      for (final text in ArchiveDepthCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        ArchiveDepthCopy.allVisibleCopy(),
        anyElement(contains('ArchiveMe')),
      );
    });

    test('does not include Buy now or Subscribe now copy', () {
      final joined = ArchiveDepthCopy.allVisibleCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });
  });

  group('Archive depth gates', () {
    test('record compact hint only after two entries and not post-save', () {
      expect(
        ArchiveDepthGates.showCompactOnRecord(
          loaded: true,
          entryCount: 1,
          isPostSave: false,
        ),
        isFalse,
      );
      expect(
        ArchiveDepthGates.showCompactOnRecord(
          loaded: true,
          entryCount: 2,
          isPostSave: false,
        ),
        isTrue,
      );
      expect(
        ArchiveDepthGates.showCompactOnRecord(
          loaded: true,
          entryCount: 3,
          isPostSave: true,
        ),
        isFalse,
      );
    });
  });

  group('Archive depth UI', () {
    testWidgets('card shows Pro preview route at 10+ entries', (tester) async {
      final result = engine.build(entries: _entries(10));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => ArchiveDepthCard(result: result),
          ),
          GoRoute(
            path: '/pro-preview',
            builder: (_, _) => const Scaffold(body: Text('pro-preview')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();

      expect(find.byKey(const Key('archive_depth_pro_line')), findsOneWidget);
      expect(
        find.byKey(const Key('archive_depth_pro_preview_button')),
        findsOneWidget,
      );
      expect(find.text('Buy now'), findsNothing);
      expect(find.text('Subscribe now'), findsNothing);

      await tester.tap(
        find.byKey(const Key('archive_depth_pro_preview_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('pro-preview'), findsOneWidget);
    });

    testWidgets('card hides Pro line below ten entries', (tester) async {
      final result = engine.build(entries: _entries(4));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ArchiveDepthCard(result: result)),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('archive_depth_pro_line')), findsNothing);
      expect(
        find.byKey(const Key('archive_depth_pro_preview_button')),
        findsNothing,
      );
    });
  });

  group('Archive depth archive home wiring', () {
    test('focused beta archive home excludes depth card widget', () {
      final src = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(src, isNot(contains('ArchiveDepthCard')));
      expect(src, isNot(contains('ArchiveDepthEngine')));
    });
  });

  group('Pro preview value section', () {
    testWidgets('shows central Pro value headline', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ProValuePreviewScreen(),
        ),
      );
      await tester.pump();
      expect(find.text(ProValueCopy.headline), findsOneWidget);
      expect(find.text(ProValueCopy.subheadline), findsOneWidget);
    });
  });
}