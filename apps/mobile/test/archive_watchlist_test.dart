import 'dart:io';

import 'package:archiveme_mobile/features/archive_export/archive_export_pack.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_copy.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_engine.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_gates.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_models.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_store.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive_watchlist_card.dart';
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
  List<String> themes = const ['work'],
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: transcript ?? _longTranscript,
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

ArchiveWatchlistItem _watchItem({
  String id = 'w1',
  String presetId = 'work_patterns',
  String? customLabel,
}) => ArchiveWatchlistItem(
  id: id,
  presetId: presetId,
  customLabel: customLabel,
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
  const engine = ArchiveWatchlistEngine();

  group('Archive watchlist gates', () {
    test('shows teaser at zero entries', () {
      expect(
        ArchiveWatchlistGates.showTeaser(entryCount: 0, sampleMode: false),
        isTrue,
      );
      expect(
        ArchiveWatchlistGates.showCard(entryCount: 0, sampleMode: false),
        isFalse,
      );
    });

    test('shows card at one or more entries', () {
      expect(
        ArchiveWatchlistGates.showCard(entryCount: 1, sampleMode: false),
        isTrue,
      );
      expect(
        ArchiveWatchlistGates.showTeaser(entryCount: 1, sampleMode: false),
        isFalse,
      );
    });
  });

  group('Archive watchlist store', () {
    test('persists preset and custom watch themes locally', () async {
      final tempDir = Directory.systemTemp.createTempSync('watchlist_store_');
      final store = await ArchiveWatchlistStore.open(
        '${tempDir.path}/prefs.json',
      );

      final preset = ArchiveWatchlistItem(
        id: 'w1',
        presetId: 'work_patterns',
        createdAt: DateTime(2026, 6, 10),
      );
      final custom = ArchiveWatchlistItem(
        id: 'w2',
        presetId: ArchiveWatchlistItem.customPresetId,
        customLabel: 'Sunday planning',
        createdAt: DateTime(2026, 6, 11),
      );

      await store.addItem(preset);
      await store.addItem(custom);
      final loaded = await store.loadItems();
      expect(loaded.length, 2);
      expect(loaded.first.presetId, 'work_patterns');
      expect(loaded.last.customLabel, 'Sunday planning');

      await store.removeItem('w1');
      final afterRemove = await store.loadItems();
      expect(afterRemove.length, 1);
      expect(afterRemove.single.id, 'w2');
    });

    test('does not use JournalStore', () {
      final storeSrc = File(
        'lib/features/archive_watchlist/archive_watchlist_store.dart',
      ).readAsStringSync();
      expect(storeSrc, isNot(contains('JournalStore')));
      expect(storeSrc, contains('archiveWatchlistItems'));
    });
  });

  group('Archive watchlist engine', () {
    test('counts related moments without exposing raw entry text', () {
      final entries = [
        _entry('e1', transcript: _longTranscript),
        _entry(
          'e2',
          transcript:
              'Another long enough saved moment about meetings and deadlines at work today.',
        ),
      ];
      final item = _watchItem();
      final result = engine.evaluateItem(item: item, entries: entries);
      expect(result.matchCount, 2);
      expect(result.label, 'Work patterns');
      expect(result.toString(), isNot(contains('meetings and deadlines')));
    });

    test('no-match state uses no clear evidence yet copy', () {
      final entries = [
        _entry(
          'e1',
          transcript:
              'A long enough transcript with no work-related keywords at all here.',
          themes: const ['rest'],
        ),
      ];
      final card = engine.build(
        entries: entries,
        items: [_watchItem(presetId: 'avoided_tasks')],
        entryCount: 1,
      );
      expect(card.itemResults.single.matchCount, 0);
      expect(card.itemResults.single.hasMatches, isFalse);
    });

    test('match state uses early evidence wording', () {
      final entries = [
        _entry(
          'e1',
          transcript:
              'I keep putting off the report and procrastinating on this task again today.',
        ),
      ];
      final card = engine.build(
        entries: entries,
        items: [_watchItem(presetId: 'avoided_tasks')],
        entryCount: 1,
      );
      expect(card.itemResults.single.matchCount, 1);
      expect(card.itemResults.single.hasMatches, isTrue);
    });

    test('custom theme matches tokenized label words', () {
      final entries = [
        _entry(
          'e1',
          transcript:
              'Sunday planning felt scattered and I wrote about what to focus on next.',
        ),
      ];
      final item = _watchItem(
        presetId: ArchiveWatchlistItem.customPresetId,
        customLabel: 'Sunday planning',
      );
      final result = engine.evaluateItem(item: item, entries: entries);
      expect(result.matchCount, 1);
    });

    test('Pro line appears at three themes or ten entries', () {
      final threeThemes = engine.build(
        entries: [_entry('e1')],
        items: [
          _watchItem(),
          _watchItem(id: 'w2', presetId: 'avoided_tasks'),
          _watchItem(id: 'w3', presetId: 'repeated_thoughts'),
        ],
        entryCount: 2,
      );
      expect(threeThemes.showProLine, isTrue);

      final tenEntries = engine.build(
        entries: List.generate(10, (i) => _entry('e$i')),
        items: [_watchItem()],
        entryCount: 10,
      );
      expect(tenEntries.showProLine, isTrue);

      final belowThreshold = engine.build(
        entries: [_entry('e1')],
        items: [_watchItem()],
        entryCount: 2,
      );
      expect(belowThreshold.showProLine, isFalse);
    });
  });

  group('Archive watchlist copy', () {
    test('uses ArchiveMe and avoids banned language', () {
      _expectNoBannedCopy(ArchiveWatchlistCopy.allVisibleCopy());
      for (final text in ArchiveWatchlistCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        ArchiveWatchlistCopy.allVisibleCopy(),
        anyElement(contains('ArchiveMe')),
      );
    });

    test('does not include Buy now or Subscribe now copy', () {
      final joined = ArchiveWatchlistCopy.allVisibleCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });

    test('theme limit copy is honest and non-pressure', () {
      expect(
        ArchiveWatchlistCopy.themeLimitBody,
        contains('Three watch themes is enough for this version'),
      );
      expect(
        ArchiveWatchlistCopy.themeLimitBody.toLowerCase(),
        isNot(contains('must upgrade')),
      );
    });
  });

  group('Archive watchlist UI', () {
    testWidgets('teaser at zero entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ArchiveWatchlistCard.test(
              entryCount: 0,
              entries: [],
              initialItems: [],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('archive_watchlist_teaser')), findsOneWidget);
      expect(find.byKey(const Key('archive_watchlist_card')), findsNothing);
    });

    testWidgets('shows card at one entry and add preset theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveWatchlistCard.test(
              entryCount: 1,
              entries: [_entry('e1')],
              initialItems: const [],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('archive_watchlist_card')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('archive_watchlist_option_unclear_decisions')),
      );
      await tester.pump();

      expect(find.text('Watching for: Unclear decisions'), findsOneWidget);
    });

    testWidgets('Pro preview routes from card at ten entries', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => ArchiveWatchlistCard.test(
              entryCount: 10,
              entries: List.generate(10, (i) => _entry('e$i')),
              initialItems: [_watchItem()],
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
        find.byKey(const Key('archive_watchlist_pro_line')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('archive_watchlist_pro_preview_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('pro-preview'), findsOneWidget);
    });

    testWidgets('does not include Buy now or Subscribe now text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveWatchlistCard.test(
                entryCount: 3,
                entries: List.generate(3, (i) => _entry('e$i')),
                initialItems: [
                  _watchItem(),
                  _watchItem(id: 'w2', presetId: 'avoided_tasks'),
                  _watchItem(id: 'w3', presetId: 'repeated_thoughts'),
                ],
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

  group('Archive watchlist privacy boundaries', () {
    test('share-safe proof does not include watchlist data', () {
      final entries = List.generate(5, (i) => _entry('e$i'));
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: entries,
      );
      expect(proof.shareText, isNot(contains('Watching for:')));
      expect(proof.shareText, isNot(contains('archiveWatchlistItems')));
      expect(proof.shareText, isNot(contains('Unclear decisions')));
    });

    test('archive export pack does not include watchlist data', () {
      final entries = List.generate(5, (i) => _entry('e$i'));
      final pack = ArchiveExportPackEngine.build(
        entries: entries,
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains('Watching for:')));
      expect(pack.plainText, isNot(contains('archiveWatchlistItems')));
      expect(
        pack.plainText,
        isNot(contains('What should ArchiveMe watch for?')),
      );
    });

    test('focused beta archive home excludes watchlist card', () {
      final src = File(
        'lib/features/archive/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(src, isNot(contains('ArchiveWatchlistCard')));
    });

    test('journal store source is separate from watchlist store', () {
      final journalSrc = File(
        'lib/storage/journal_store.dart',
      ).readAsStringSync();
      expect(journalSrc, isNot(contains('archiveWatchlistItems')));
    });
  });
}