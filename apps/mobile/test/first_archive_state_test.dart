// Behavioral tests for the authoritative Archive screen contract.
// See docs/ARCHIVE_SCREEN_SPEC_V1.md. Previously this file asserted the
// four-state "Patterns" belief-comparison copy against ArchiveBeliefScreen;
// that behavior now lives on the Changes tab (BeliefChangesScreen) and is
// covered by test/archive_tab_four_state_test.dart and
// test/belief_changes_navigation_test.dart. Asserting it here again against
// the wrong screen was stale coverage, not real coverage, so it has been
// removed rather than ported.
import 'dart:io';

import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/screens/archive_belief_screen.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

const _archiveScope = 'local_archive_v1';
const _ownerScope = 'local_owner_v1';

JournalEntry _entry({
  String id = 'e1',
  String? transcript,
  DateTime? createdAt,
  VerifiedProof? proof,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript:
        transcript ??
        'A long enough transcript to count as a saved reflection.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
    verifiedProof: proof,
  );
}

/// Admits a real proof through the canonical pipeline rather than
/// hand-building a [VerifiedProof], so the fixture is something the gate
/// would genuinely admit.
VerifiedProof _admittedProof({
  required String entryId,
  required String transcript,
  String quote = 'said yes again',
}) {
  final transcriptRevision = UserContentSafety.privacyHash(transcript);
  final service = CanonicalProofAdmissionService(
    clock: () => DateTime.utc(2026, 7, 2),
  );
  final result = service.admit(
    raw: RawModelResponse(
      payload: {
        'reflection': {
          'mood': 'neutral',
          'emotionalIntensity': 2,
          'recurringThemes': const ['capacity'],
          'exactLanguagePattern': quote,
          'concreteObservation': 'You agreed before checking your calendar.',
          'repeatedSignal': 'This always happens.',
          'nextSmallAction': 'Say no next time.',
        },
      },
      receivedAt: DateTime.utc(2026, 7, 2),
    ),
    sourceEntries: [
      ProofSourceEntry(
        entryId: entryId,
        archiveScope: _archiveScope,
        ownerScope: _ownerScope,
        transcript: transcript,
        transcriptRevision: transcriptRevision,
        createdAt: DateTime.utc(2026, 7),
        sourceType: ProofSourceType.userVoiceTranscript,
        remoteProcessingConsented: true,
      ),
    ],
    activeArchiveScope: _archiveScope,
    activeOwnerScope: _ownerScope,
    primarySourceEntryId: entryId,
  );
  expect(
    result,
    isA<ProofAdmitted>(),
    reason: 'fixture proof must be admissible for the test to be meaningful',
  );
  return (result as ProofAdmitted).proof;
}

Future<void> _applyArchiveSearch(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const Key('archive_search_field')),
    query,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 50; attempt++) {
      final state = appProviderContainer.read(archiveFeedPaginationProvider);
      if (state.loadState == ArchiveBeliefLoadState.loaded &&
          state.searchQuery == query.trim()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
}

Future<void> _resetServices() async {
  final tmp = await Directory.systemTemp.createTemp('vm_first_archive_');
  await AppServices.resetForTest(
    journalPath: '${tmp.path}/journal.json',
    prefsPath: '${tmp.path}/prefs.json',
    skipRevenueCat: true,
  );
}

Future<void> _pumpArchive(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: ArchiveBeliefScreen(key: UniqueKey()),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    await appProviderContainer
        .read(archiveFeedPaginationProvider.notifier)
        .refresh();
  });
  await tester.pump();
  for (var attempt = 0; attempt < 10; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('archive_loading_indicator')).evaluate().isEmpty) {
      break;
    }
  }
}

void main() {
  setUp(() async {
    await _resetServices();
  });

  group('ArchiveBeliefScreen — empty and populated states', () {
    testWidgets('zero entries shows the empty-archive card and a Record CTA', (
      tester,
    ) async {
      await _pumpArchive(tester);

      expect(
        find.byKey(const Key('archive_tab_entry_state_empty')),
        findsOneWidget,
      );
      expect(find.text('Go to Record'), findsOneWidget);
      expect(find.byKey(const Key('archive_search_field')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'one saved entry renders as an original moment, no search bar',
      (tester) async {
        await tester.runAsync(() async {
          await AppServices.instance.journalStore.save(_entry());
        });

        await _pumpArchive(tester);

        expect(find.text('Original moments'), findsOneWidget);
        expect(find.textContaining('A long enough transcript'), findsOneWidget);
        // A single entry has nothing to search across yet.
        expect(find.byKey(const Key('archive_search_field')), findsNothing);
      },
    );

    testWidgets(
      'two saved entries show a search field that filters by content',
      (tester) async {
        await tester.runAsync(() async {
          await AppServices.instance.journalStore.save(
            _entry(id: 'a', transcript: 'Talked with my manager about scope.'),
          );
          await AppServices.instance.journalStore.save(
            _entry(id: 'b', transcript: 'A quiet evening walk with no agenda.'),
          );
        });

        await _pumpArchive(tester);

        expect(find.byKey(const Key('archive_search_field')), findsOneWidget);
        expect(find.textContaining('Talked with my manager'), findsOneWidget);
        expect(find.textContaining('A quiet evening walk'), findsOneWidget);

        await _applyArchiveSearch(tester, 'manager');

        expect(find.textContaining('Talked with my manager'), findsOneWidget);
        expect(find.textContaining('A quiet evening walk'), findsNothing);
        expect(
          find.byKey(const Key('archive_search_no_results')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a search with no matches shows a no-results message, not an empty archive',
      (tester) async {
        await tester.runAsync(() async {
          await AppServices.instance.journalStore.save(
            _entry(id: 'a', transcript: 'Talked with my manager about scope.'),
          );
          await AppServices.instance.journalStore.save(
            _entry(id: 'b', transcript: 'A quiet evening walk with no agenda.'),
          );
        });

        await _pumpArchive(tester);
        await _applyArchiveSearch(tester, 'zzz-no-such-word');

        expect(
          find.byKey(const Key('archive_search_no_results')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('archive_tab_entry_state_empty')),
          findsNothing,
        );
      },
    );
  });

  group('ArchiveBeliefScreen — verified changes gating', () {
    testWidgets('absent when no entry carries a verified proof', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry());
      });

      await _pumpArchive(tester);

      expect(
        find.byKey(const Key('archive_verified_changes_heading')),
        findsNothing,
      );
      expect(find.text('Original moments'), findsOneWidget);
    });

    testWidgets(
      'appears, gated through the canonical proof pipeline, once a proof is admitted',
      (tester) async {
        const transcript = 'I said yes again before checking my calendar.';
        final proof = _admittedProof(
          entryId: 'proof-entry',
          transcript: transcript,
        );

        await tester.runAsync(() async {
          await AppServices.instance.journalStore.save(
            _entry(id: 'proof-entry', transcript: transcript, proof: proof),
          );
        });

        await _pumpArchive(tester);

        expect(
          find.byKey(const Key('archive_verified_changes_heading')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('archive_verified_change_proof-entry')),
          findsOneWidget,
        );
        // The card renders the plain-language statement, never a raw score.
        final rendered = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data ?? '')
            .join(' ')
            .toLowerCase();
        expect(rendered, isNot(contains('qualityreceipt')));
        expect(rendered, isNot(contains('%')));
      },
    );

    testWidgets(
      'disappears again once the quoted transcript no longer matches (fails closed)',
      (tester) async {
        const originalTranscript =
            'I said yes again before checking my calendar.';
        final proof = _admittedProof(
          entryId: 'edited-entry',
          transcript: originalTranscript,
        );

        await tester.runAsync(() async {
          // The entry now on disk has a different transcript than the one the
          // proof was admitted against, so re-verification must withdraw it.
          await AppServices.instance.journalStore.save(
            _entry(
              id: 'edited-entry',
              transcript: 'A completely different, edited transcript now.',
              proof: proof,
            ),
          );
        });

        await _pumpArchive(tester);

        expect(
          find.byKey(const Key('archive_verified_changes_heading')),
          findsNothing,
        );
      },
    );
  });

  group('App restart persistence', () {
    test('saved entry persists across journal store reopen', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_restart_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final journalPath = '${tempDir.path}/entries.json';

      final store = await JournalStore.open(journalPath, encryptAtRest: false);
      await store.save(_entry(id: 'persist1'));

      final reopened = await JournalStore.open(
        journalPath,
        encryptAtRest: false,
      );
      final entries = await reopened.loadAll();

      expect(entries.length, 1);
      expect(entries.first.id, 'persist1');
    });
  });

  group('Layout and brand safety', () {
    const surfaces = <MapEntry<String, Size>>[
      MapEntry('iphone_17_pro', Size(402, 874)),
      MapEntry('small_android', Size(360, 640)),
    ];

    for (final surface in surfaces) {
      testWidgets('no overflow on ${surface.key}', (tester) async {
        await tester.binding.setSurfaceSize(surface.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.runAsync(() async {
          await AppServices.instance.journalStore.save(_entry());
        });
        await _pumpArchive(tester);

        expect(tester.takeException(), isNull);
        expect(find.textContaining('VoiceMemory'), findsNothing);
        expect(find.textContaining('ChatGPT'), findsNothing);
        expect(find.textContaining('OpenAI'), findsNothing);
      });
    }
  });

  group('Accessibility', () {
    testWidgets(
      'entry cards have a real semantic label and exclude decorative internals',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.runAsync(() async {
          await AppServices.instance.journalStore.save(_entry());
        });
        await _pumpArchive(tester);

        final dateLabel = DateFormat.yMMMMd().add_jm().format(
          DateTime(2026, 6, 12, 10).toLocal(),
        );
        expect(
          find.bySemanticsLabel('Voice saved moment from $dateLabel'),
          findsOneWidget,
          reason: 'the entry card must expose a real label to a screen reader',
        );
        // The card's date/source/transcript Text children are excluded from
        // the tree so a screen reader announces the one composed label once,
        // not the label followed by each internal transcript line again.
        expect(
          find.bySemanticsLabel(RegExp('A long enough transcript')),
          findsNothing,
        );
        handle.dispose();
      },
    );

    testWidgets('archive load error is announced via a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(source, contains('liveRegion: true'));
      expect(source, contains('Your archive could not be opened right now.'));
      handle.dispose();
    });

    testWidgets('remains usable at 200% text scale with no overflow', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry());
        await AppServices.instance.journalStore.save(
          _entry(id: 'e2', transcript: 'A second long enough transcript.'),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ArchiveBeliefScreen(key: UniqueKey()),
        ),
      );
      await tester.pump();
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find
            .byKey(const Key('archive_loading_indicator'))
            .evaluate()
            .isEmpty) {
          break;
        }
      }

      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}