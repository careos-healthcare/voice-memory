import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/archive_evidence_map.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/archive_evidence_map_card.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
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
      captureContextTag: captureContextTag,
    );

JournalEntry _degradedVoiceEntry({
  String id = 'd1',
  String? captureContextTag,
}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      durationSeconds: 20,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      captureContextTag: captureContextTag,
    );

List<JournalEntry> _mixedEntries() => [
      _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired moment one.',
        captureContextTag: CaptureContextTagIds.work,
      ),
      _voiceEntry(
        id: 'e2',
        transcript:
            'Work kept pulling me back after I wanted to stop for the day moment two.',
        createdAt: DateTime(2026, 6, 11),
        captureContextTag: CaptureContextTagIds.work,
      ),
      _voiceEntry(
        id: 'e3',
        transcript:
            'Home felt loud before I could settle into the evening moment three.',
        createdAt: DateTime(2026, 6, 10),
        captureContextTag: CaptureContextTagIds.home,
      ),
      _voiceEntry(
        id: 'e4',
        transcript:
            'Another untagged moment before I could leave for the day moment four.',
        createdAt: DateTime(2026, 6, 9),
      ),
      _degradedVoiceEntry(
        id: 'd1',
        captureContextTag: CaptureContextTagIds.work,
      ),
    ];

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
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
  group('ArchiveEvidenceMapEngine drilldown', () {
    test('Work drilldown shows only eligible Work entries', () {
      final work = ArchiveEvidenceMapEngine.eligibleEntriesForContext(
        entries: _mixedEntries(),
        contextTagId: CaptureContextTagIds.work,
      );
      expect(work.map((entry) => entry.id), ['e1', 'e2']);
      expect(work.every((entry) => entry.captureContextTag == CaptureContextTagIds.work), isTrue);
    });

    test('Untagged drilldown shows only eligible untagged entries', () {
      final untagged = ArchiveEvidenceMapEngine.eligibleEntriesForContext(
        entries: _mixedEntries(),
        contextTagId: ArchiveEvidenceMapRowIds.untagged,
      );
      expect(untagged.map((entry) => entry.id), ['e4']);
      expect(
        untagged.every(
          (entry) =>
              entry.captureContextTag == null || entry.captureContextTag!.isEmpty,
        ),
        isTrue,
      );
    });

    test('degraded and blank entries are excluded from drilldown', () {
      final work = ArchiveEvidenceMapEngine.eligibleEntriesForContext(
        entries: _mixedEntries(),
        contextTagId: CaptureContextTagIds.work,
      );
      expect(work.any((entry) => entry.id == 'd1'), isFalse);

      final blankTagged = ArchiveEvidenceMapEngine.eligibleEntriesForContext(
        entries: [
          _voiceEntry(
            id: 'blank',
            transcript: '   ',
            captureContextTag: CaptureContextTagIds.work,
          ),
        ],
        contextTagId: CaptureContextTagIds.work,
      );
      expect(blankTagged, isEmpty);
    });

    test('empty context shows graceful empty drilldown copy', () {
      final drilldown = ArchiveEvidenceMapEngine.buildContextDrilldown(
        entries: _mixedEntries(),
        contextTagId: CaptureContextTagIds.money,
      );
      expect(drilldown.isEmpty, isTrue);
      expect(
        drilldown.emptyBody,
        VisibleArchiveProofCopy.archiveEvidenceContextEmpty,
      );
      expect(
        drilldown.title,
        VisibleArchiveProofCopy.archiveEvidenceContextTitle('Money'),
      );
    });

    test('untagged drilldown uses untagged title', () {
      final drilldown = ArchiveEvidenceMapEngine.buildContextDrilldown(
        entries: _mixedEntries(),
        contextTagId: ArchiveEvidenceMapRowIds.untagged,
      );
      expect(
        drilldown.title,
        VisibleArchiveProofCopy.archiveEvidenceContextUntaggedTitle,
      );
      expect(drilldown.subtitle, VisibleArchiveProofCopy.archiveEvidenceContextSubtitle);
    });

    test('manual tag edit changes which drilldown an entry belongs to', () async {
      final tmp = await Directory.systemTemp.createTemp('evidence_drilldown_tag_');
      final store = await JournalStore.open('${tmp.path}/entries.json');
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
        captureContextTag: CaptureContextTagIds.work,
      );
      await store.save(entry);

      var entries = [entry];
      expect(
        ArchiveEvidenceMapEngine.eligibleEntriesForContext(
          entries: entries,
          contextTagId: CaptureContextTagIds.work,
        ).map((e) => e.id),
        ['e1'],
      );

      await store.updateCaptureContextTag('e1', tagId: CaptureContextTagIds.home);
      final updated = await store.getById('e1');
      entries = [updated!];

      expect(
        ArchiveEvidenceMapEngine.eligibleEntriesForContext(
          entries: entries,
          contextTagId: CaptureContextTagIds.work,
        ),
        isEmpty,
      );
      expect(
        ArchiveEvidenceMapEngine.eligibleEntriesForContext(
          entries: entries,
          contextTagId: CaptureContextTagIds.home,
        ).map((e) => e.id),
        ['e1'],
      );
    });

    test('share-safe proof does not include context drilldown data', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: _mixedEntries(),
      );
      final shareText = proof.lines.join('\n').toLowerCase();
      expect(shareText, isNot(contains('evidence in work')));
      expect(shareText, isNot(contains('untagged evidence')));
      expect(shareText, isNot(contains('saved moments counted in your evidence map')));
    });

    test('copy avoids banned language', () {
      final drilldown = ArchiveEvidenceMapEngine.buildContextDrilldown(
        entries: _mixedEntries(),
        contextTagId: CaptureContextTagIds.work,
      );
      _expectNoBannedCopy([
        drilldown.title,
        drilldown.subtitle,
        drilldown.emptyBody,
        VisibleArchiveProofCopy.archiveEvidenceContextOpenEntry,
      ]);
    });
  });

  group('ArchiveEvidenceMapNavigation', () {
    test('context route path is stable', () {
      expect(
        ArchiveEvidenceMapNavigation.contextPath(CaptureContextTagIds.work),
        '/archive-evidence-map/context/work',
      );
      expect(
        ArchiveEvidenceMapNavigation.contextPath(ArchiveEvidenceMapRowIds.untagged),
        '/archive-evidence-map/context/untagged',
      );
    });

    test('context route is marked sensitive', () {
      expect(
        SensitiveRoutes.isSensitiveRoute(
          ArchiveEvidenceMapNavigation.contextPath(CaptureContextTagIds.work),
        ),
        isTrue,
      );
      expect(
        SensitiveRoutes.isSensitiveRoute(
          ArchiveEvidenceMapNavigation.contextPath(ArchiveEvidenceMapRowIds.untagged),
        ),
        isTrue,
      );
    });
  });

  group('ArchiveEvidenceMapCard drilldown tap', () {
    testWidgets('row tap invokes callback with context id', (tester) async {
      final map = ArchiveEvidenceMapEngine.build(entries: _mixedEntries());
      String? tappedId;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SingleChildScrollView(
            child: ArchiveEvidenceMapCard(
              map: map,
              onRowTap: (tagId) => tappedId = tagId,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('archive_evidence_map_row_tap_work')));
      await tester.pump();
      expect(tappedId, CaptureContextTagIds.work);

      await tester.tap(find.byKey(const Key('archive_evidence_map_row_tap_untagged')));
      await tester.pump();
      expect(tappedId, ArchiveEvidenceMapRowIds.untagged);
    });
  });

  group('Evidence map drilldown navigation', () {
    testWidgets('row tap pushes guarded context route', (tester) async {
      final map = ArchiveEvidenceMapEngine.build(entries: _mixedEntries());
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: ArchiveEvidenceMapCard(
                  map: map,
                  onRowTap: (tagId) => context.push(
                    ArchiveEvidenceMapNavigation.contextPath(tagId),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: ArchiveEvidenceMapNavigation.contextRoute,
            builder: (context, state) {
              final tagId = state.pathParameters['tagId'] ?? '';
              final drilldown = ArchiveEvidenceMapEngine.buildContextDrilldown(
                entries: _mixedEntries(),
                contextTagId: tagId,
              );
              return Scaffold(
                body: drilldown.isEmpty
                    ? Text(
                        drilldown.emptyBody,
                        key: const Key('archive_evidence_context_empty'),
                      )
                    : Text(
                        drilldown.title,
                        key: const Key('archive_evidence_context_screen_title'),
                      ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('archive_evidence_map_row_tap_work')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('archive_evidence_context_screen_title')), findsOneWidget);
      expect(find.text('Evidence in Work'), findsOneWidget);
    });
  });
}
