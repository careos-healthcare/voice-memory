import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/archive_export/archive_export_pack.dart';
import 'package:voicememory_mobile/features/archive_watchlist/archive_watchlist_models.dart';
import 'package:voicememory_mobile/features/moment_quality/moment_quality_models.dart';
import 'package:voicememory_mobile/features/next_evidence_plan/next_evidence_plan_copy.dart';
import 'package:voicememory_mobile/features/next_evidence_plan/next_evidence_plan_engine.dart';
import 'package:voicememory_mobile/features/next_evidence_plan/next_evidence_plan_gates.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/return_ritual/return_ritual_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/next_evidence_plan_card.dart';

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
    'Work pressure showed up again today and I noticed the same tight feeling at the office.';

JournalEntry _entry(
  String id, {
  String? transcript,
  DateTime? createdAt,
  String? captureContextTag,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript ?? _longTranscript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  captureContextTag: captureContextTag,
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: const ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _entries(int count) => List.generate(
  count,
  (i) => _entry('e$i', createdAt: DateTime(2026, 6, 10 + i)),
);

ArchiveWatchlistItem _watchItem({
  String id = 'w1',
  String presetId = 'unclear_decisions',
}) => ArchiveWatchlistItem(
  id: id,
  presetId: presetId,
  createdAt: DateTime(2026, 6, 10),
);

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
  const engine = NextEvidencePlanEngine();

  group('Next evidence plan gates', () {
    test('shows teaser at zero entries', () {
      expect(
        NextEvidencePlanGates.showTeaser(entryCount: 0, sampleMode: false),
        isTrue,
      );
      expect(
        NextEvidencePlanGates.showCard(entryCount: 0, sampleMode: false),
        isFalse,
      );
    });

    test('hidden on sample archive mode', () {
      expect(
        NextEvidencePlanGates.showTeaser(entryCount: 0, sampleMode: true),
        isFalse,
      );
      expect(
        NextEvidencePlanGates.showCard(entryCount: 5, sampleMode: true),
        isFalse,
      );
    });

    test('shows card at one or more entries', () {
      expect(
        NextEvidencePlanGates.showCard(entryCount: 1, sampleMode: false),
        isTrue,
      );
    });
  });

  group('Next evidence plan engine entry bands', () {
    test('1 entry suggests adding one more moment', () {
      final result = engine.build(
        entries: [_entry('e1')],
        watchlistItems: const [],
      );
      expect(result.body, NextEvidencePlanCopy.oneEntryBody);
    });

    test('2 entries suggests confirm change or challenge pattern', () {
      final result = engine.build(
        entries: _entries(2),
        watchlistItems: const [],
      );
      expect(result.body, NextEvidencePlanCopy.twoEntriesBody);
    });

    test('3–4 entries suggests testing whether belief still fits', () {
      for (final count in [3, 4]) {
        final result = engine.build(
          entries: _entries(count),
          watchlistItems: const [],
        );
        expect(result.body, NextEvidencePlanCopy.beliefTestBody);
      }
    });

    test('5+ entries suggests next weekly review evidence', () {
      final result = engine.build(
        entries: _entries(5),
        watchlistItems: const [],
      );
      expect(result.body, NextEvidencePlanCopy.weeklyReviewBody);
    });
  });

  group('Next evidence plan engine signals', () {
    test('watchlist theme takes priority when present', () {
      final result = engine.build(
        entries: _entries(5),
        watchlistItems: [_watchItem()],
      );
      expect(
        result.body,
        NextEvidencePlanCopy.watchlistPlanBody('Unclear decisions'),
      );
      expect(
        result.watchlistLine,
        NextEvidencePlanCopy.watchingForLine('Unclear decisions'),
      );
    });

    test('return ritual phrase appears when present', () {
      final result = engine.build(
        entries: _entries(2),
        watchlistItems: const [],
        returnRitualPhrase: 'At the end of the workday',
      );
      expect(
        result.returnRitualLine,
        NextEvidencePlanCopy.returnRitualLine('At the end of the workday'),
      );
    });

    test('untagged context suggests context improvement', () {
      final entries = [
        _entry('e1', captureContextTag: CaptureContextTagIds.work),
        _entry('e2'),
      ];
      final result = engine.build(entries: entries, watchlistItems: const []);
      expect(
        result.secondaryLine,
        NextEvidencePlanCopy.contextImprovementSuggestion,
      );
    });

    test('very short recent entry suggests one extra detail', () {
      final entries = [
        _entry('e1'),
        _entry('e2', transcript: 'Too short', createdAt: DateTime(2026, 6, 15)),
      ];
      final result = engine.build(entries: entries, watchlistItems: const []);
      expect(result.secondaryLine, NextEvidencePlanCopy.extraDetailSuggestion);
    });

    test('Pro line appears only at 10+ entries or 3 watch themes', () {
      expect(
        engine
            .build(entries: _entries(9), watchlistItems: [_watchItem()])
            .showProLine,
        isFalse,
      );
      expect(
        engine
            .build(entries: _entries(10), watchlistItems: [_watchItem()])
            .showProLine,
        isTrue,
      );
      expect(
        engine
            .build(
              entries: _entries(3),
              watchlistItems: [
                _watchItem(id: 'w1'),
                _watchItem(id: 'w2', presetId: 'work_patterns'),
                _watchItem(id: 'w3', presetId: 'avoided_tasks'),
              ],
            )
            .showProLine,
        isTrue,
      );
    });

    test('does not expose raw entry text in result', () {
      const sensitive = 'Maria told me about divorce paperwork at the hospital';
      final result = engine.build(
        entries: [_entry('e1', transcript: sensitive)],
        watchlistItems: const [],
      );
      expect(result.toString(), isNot(contains('Maria')));
      expect(result.body, isNot(contains('divorce')));
    });
  });

  group('Next evidence plan copy', () {
    test('uses ArchiveMe and avoids banned language', () {
      _expectNoBannedCopy(NextEvidencePlanCopy.allVisibleCopy());
      for (final text in NextEvidencePlanCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        NextEvidencePlanCopy.allVisibleCopy(),
        anyElement(contains('ArchiveMe')),
      );
    });

    test('does not include Buy now or Subscribe now copy', () {
      final joined = NextEvidencePlanCopy.allVisibleCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });
  });

  group('Next evidence plan UI', () {
    testWidgets('teaser at zero entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: NextEvidencePlanCard.test(
              entryCount: 0,
              entries: [],
              initialWatchlistItems: [],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('next_evidence_plan_teaser')),
        findsOneWidget,
      );
    });

    testWidgets('Pro preview routes at ten entries', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => NextEvidencePlanCard.test(
              entryCount: 10,
              entries: _entries(10),
              initialWatchlistItems: const [],
            ),
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

      expect(
        find.byKey(const Key('next_evidence_plan_pro_line')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('next_evidence_plan_pro_preview_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('pro-preview'), findsOneWidget);
    });

    testWidgets('does not include Buy now or Subscribe now text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: NextEvidencePlanCard.test(
              entryCount: 3,
              entries: _entries(3),
              initialWatchlistItems: [_watchItem()],
              initialReturnRitual: const ReturnRitualChoice(
                presetId: 'end_workday',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Buy now'), findsNothing);
      expect(find.text('Subscribe now'), findsNothing);
    });
  });

  group('Next evidence plan privacy boundaries', () {
    test('does not write to JournalStore', () {
      final engineSrc = File(
        'lib/features/next_evidence_plan/next_evidence_plan_engine.dart',
      ).readAsStringSync();
      expect(engineSrc, isNot(contains('JournalStore')));
    });

    test('share-safe proof excludes plan text', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: _entries(5),
      );
      expect(proof.shareText, isNot(contains('Next evidence plan')));
      expect(proof.shareText, isNot(contains('next evidence plan')));
    });

    test('archive export pack excludes plan text', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _entries(5),
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains('Next evidence plan')));
    });

    test('archive belief screen wires plan card and hides on sample mode', () {
      final src = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(src, contains('NextEvidencePlanCard'));
      expect(src, contains('NextEvidencePlanGates'));
      expect(src, contains('sampleMode: ScreenshotMode.enabled'));
    });
  });
}
