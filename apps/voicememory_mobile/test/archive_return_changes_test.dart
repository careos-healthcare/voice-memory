import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/weekly_archive_review.dart';
import 'package:voicememory_mobile/features/return_changes/archive_return_changes_copy.dart';
import 'package:voicememory_mobile/features/return_changes/archive_return_changes_engine.dart';
import 'package:voicememory_mobile/features/return_changes/archive_return_changes_gates.dart';
import 'package:voicememory_mobile/features/return_changes/archive_return_changes_store.dart';
import 'package:voicememory_mobile/features/return_changes/archive_return_snapshot.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_return_changes_card.dart';

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

JournalEntry _entry(
  String id, {
  required String transcript,
  DateTime? createdAt,
  List<String> themes = const ['work'],
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: themes,
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _fourWorkEntries() => [
  _entry(
    'e1',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired.',
    createdAt: DateTime(2026, 6, 9, 12),
  ),
  _entry(
    'e2',
    transcript:
        'Work kept pulling me back after I wanted to stop for the day at the office.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    'e3',
    transcript:
        'I noticed the same hurry showing up before I answered anyone at work.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    'e4',
    transcript:
        'The deadline pressure returned, but I caught it earlier this time.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _fiveWorkEntries() => [
  ..._fourWorkEntries(),
  _entry(
    'e5',
    transcript:
        'At home after work I still replayed the meeting and what I said to my team.',
    createdAt: DateTime(2026, 6, 13, 12),
    themes: const ['work', 'home'],
  ),
];

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
  TestWidgetsFlutterBinding.ensureInitialized();
  const engine = ArchiveReturnChangesEngine();

  group('Archive return changes copy', () {
    test('uses ArchiveMe branding and avoids banned language', () {
      _expectNoBannedCopy(ArchiveReturnChangesCopy.allVisibleCopy());
      for (final text in ArchiveReturnChangesCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
    });
  });

  group('Archive return changes gates', () {
    test('hidden at zero entries', () {
      expect(
        ArchiveReturnChangesGates.show(
          entryCount: 0,
          sampleMode: false,
          result: null,
        ),
        isFalse,
      );
    });

    test('hidden on sample mode', () {
      expect(
        ArchiveReturnChangesGates.show(
          entryCount: 3,
          sampleMode: true,
          result: _sampleResult(),
        ),
        isFalse,
      );
    });

    test('hidden when no meaningful change', () {
      expect(
        ArchiveReturnChangesGates.show(
          entryCount: 3,
          sampleMode: false,
          result: null,
        ),
        isFalse,
      );
    });
  });

  group('Archive return changes engine', () {
    test('hidden when no meaningful change since last seen', () {
      final current = ArchiveReturnSnapshot.fromEntries(_fourWorkEntries());
      expect(engine.evaluate(lastSeen: current, current: current), isNull);
    });

    test('shows new evidence when entry count increased', () {
      final twoEntries = _fourWorkEntries().take(2).toList();
      final lastSeen = ArchiveReturnSnapshot.fromEntries(twoEntries);
      final current = ArchiveReturnSnapshot.fromEntries(
        _fourWorkEntries().take(3).toList(),
      );
      final result = engine.evaluate(lastSeen: lastSeen, current: current);
      expect(result?.type, ArchiveReturnChangeType.newEvidence);
      expect(result?.title, ArchiveReturnChangesCopy.newEvidenceTitle);
      expect(result?.newMomentsCount, 1);
    });

    test('shows belief changed when belief summary changes', () {
      const lastSeen = ArchiveReturnSnapshot(
        entryCount: 4,
        usableEvidenceCount: 4,
        beliefSummaryHash: '111',
        contextCount: 1,
        weeklyReviewAvailable: false,
      );
      const current = ArchiveReturnSnapshot(
        entryCount: 4,
        usableEvidenceCount: 4,
        beliefSummaryHash: '222',
        contextCount: 1,
        weeklyReviewAvailable: false,
      );
      final result = engine.evaluate(lastSeen: lastSeen, current: current);
      expect(result?.type, ArchiveReturnChangeType.beliefUpdated);
      expect(result?.reviewRoute, '/belief-changes');
    });

    test('shows evidence map changed when context summary changes', () {
      const lastSeen = ArchiveReturnSnapshot(
        entryCount: 4,
        usableEvidenceCount: 4,
        beliefSummaryHash: 'same',
        contextCount: 1,
        weeklyReviewAvailable: false,
      );
      const current = ArchiveReturnSnapshot(
        entryCount: 4,
        usableEvidenceCount: 4,
        beliefSummaryHash: 'same',
        contextCount: 3,
        weeklyReviewAvailable: false,
      );
      final result = engine.evaluate(lastSeen: lastSeen, current: current);
      expect(result?.type, ArchiveReturnChangeType.contextChanged);
      expect(result?.body, ArchiveReturnChangesCopy.contextChangedBody);
    });

    test('shows weekly review available at five usable entries', () {
      final lastSeen = ArchiveReturnSnapshot.fromEntries(_fourWorkEntries());
      final current = ArchiveReturnSnapshot.fromEntries(_fiveWorkEntries());
      expect(current.weeklyReviewAvailable, isTrue);
      expect(lastSeen.weeklyReviewAvailable, isFalse);

      final result = engine.evaluate(lastSeen: lastSeen, current: current);
      expect(result?.type, ArchiveReturnChangeType.weeklyReviewReady);
      expect(result?.reviewRoute, WeeklyArchiveReviewNavigation.route);
    });

    test('optional Pro line appears at five or more entries only', () {
      final lastSeen = ArchiveReturnSnapshot.fromEntries(_fourWorkEntries());
      final current = ArchiveReturnSnapshot.fromEntries(_fiveWorkEntries());
      final result = engine.evaluate(lastSeen: lastSeen, current: current);
      expect(result?.showProLine, isTrue);

      final small = engine.evaluate(
        lastSeen: ArchiveReturnSnapshot.fromEntries(
          _fourWorkEntries().take(2).toList(),
        ),
        current: ArchiveReturnSnapshot.fromEntries(
          _fourWorkEntries().take(3).toList(),
        ),
      );
      expect(small?.showProLine, isFalse);
    });
  });

  group('Archive return changes snapshot', () {
    late Directory tempDir;
    test('does not store raw entry text', () async {
      final entries = _fourWorkEntries();
      final snapshot = ArchiveReturnSnapshot.fromEntries(entries);
      final json = jsonEncode(snapshot.toJson());
      for (final entry in entries) {
        expect(json, isNot(contains(entry.transcript)));
      }
    });

    test('mark as seen updates local snapshot', () async {
      final tempDir = Directory.systemTemp.createTempSync('return_changes_');
      final store = await ArchiveReturnChangesStore.open(
        '${tempDir.path}/prefs.json',
      );
      final current = ArchiveReturnSnapshot.fromEntries(_fourWorkEntries());
      await store.markSeen(current);
      final loaded = await store.loadLastSeen();
      expect(loaded?.entryCount, 4);
      expect(loaded?.usableEvidenceCount, current.usableEvidenceCount);
    });
  });

  group('Archive return changes store resolve', () {
    test('seeds baseline on first visit with two or more entries', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'return_changes_seed_',
      );
      final store = await ArchiveReturnChangesStore.open(
        '${tempDir.path}/prefs.json',
      );
      final entries = _fourWorkEntries().take(2).toList();
      final resolved = await resolveArchiveReturnChanges(
        entries: entries,
        store: store,
      );
      expect(resolved.result, isNull);
      expect((await store.loadLastSeen())?.entryCount, 2);
    });
  });

  group('Archive return changes UI', () {
    testWidgets('card links to review and evidence map routes', (tester) async {
      final result = engine.evaluate(
        lastSeen: ArchiveReturnSnapshot.fromEntries(_fourWorkEntries()),
        current: ArchiveReturnSnapshot.fromEntries(_fiveWorkEntries()),
      )!;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                ArchiveReturnChangesCard(result: result, onMarkSeen: () {}),
          ),
          GoRoute(
            path: WeeklyArchiveReviewNavigation.route,
            builder: (_, _) => const Scaffold(body: Text('weekly-review')),
          ),
          GoRoute(
            path: '/archive-belief',
            builder: (_, _) => const Scaffold(body: Text('archive-belief')),
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

      await tester.tap(
        find.byKey(const Key('archive_return_changes_review_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('weekly-review'), findsOneWidget);

      router.go('/');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(
        find.byKey(const Key('archive_return_changes_evidence_map_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('archive-belief'), findsOneWidget);

      if (result.showProLine) {
        expect(
          find.byKey(const Key('archive_return_changes_pro_preview_link')),
          findsOneWidget,
        );
      }
    });

    testWidgets('does not include Buy now or Subscribe now copy', (
      tester,
    ) async {
      final result = _sampleResult();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveReturnChangesCard(result: result, onMarkSeen: () {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Buy now'), findsNothing);
      expect(find.text('Subscribe now'), findsNothing);
    });
  });
}

ArchiveReturnChangesResult _sampleResult() => const ArchiveReturnChangesResult(
  type: ArchiveReturnChangeType.newEvidence,
  title: ArchiveReturnChangesCopy.newEvidenceTitle,
  body: 'You added 1 more moment since your last review.',
  reviewRoute: '/archive-belief',
  showProLine: false,
  newMomentsCount: 1,
);
