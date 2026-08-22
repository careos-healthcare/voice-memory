import 'dart:io';

import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/memory/clean_slate_prompt_store.dart';
import 'package:archiveme_mobile/features/memory/entry_memory_mode.dart';
import 'package:archiveme_mobile/features/memory/entry_thread_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/topic_shift_guard.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/trust/aha_proof_share_eligibility.dart';
import 'package:archiveme_mobile/features/trust/archive_trust_receipt.dart';
import 'package:archiveme_mobile/features/trust/pro_trust_copy.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/screens/record_screen.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/capture_entry_actions.dart';
import 'package:archiveme_mobile/widgets/memory/clean_slate_prompt_card.dart';
import 'package:archiveme_mobile/widgets/record/evidence_context_tag_card.dart';
import 'package:archiveme_mobile/widgets/share/aha_proof_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/app_services_test_lifecycle.dart';
import 'support/expand_advanced_save_options.dart';
import 'support/memory_pressure_stores.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const _smallScreen = Size(360, 640);

const _bannedWords = [
  'always',
  'never',
  'proves',
  'definitely',
  'diagnosis',
  'diagnose',
  'therapy',
  'treatment',
  'fixed',
  'broken',
  'problem',
  'failure',
  'lazy',
  'weak',
  'must',
  'should',
  'surveillance',
  'spying',
  'tracking',
  'VoiceMemory',
];

JournalEntry _entry({
  required String id,
  DateTime? createdAt,
  bool isPinned = false,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: 'A long enough transcript for record overflow tests here.',
  durationSeconds: 20,
  isPinned: isPinned,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Observation text.',
    repeatedSignal: 'signal',
  ),
);

PressureCheckInRecord _pressureRec({
  required String id,
  required int daysAgo,
  String? archiveThreadId,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: 'could_not_stop',
  contextIds: const ['work'],
  fear: 'I keep circling the same work decision',
  archiveThreadId: archiveThreadId,
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('record_overflow_test_');
    _events.clear();
    MemoryScopePolicy.resetForTest();
    EntryMemoryModeSession.resetSessionForTest();
    EntryThreadScopeSession.resetAfterSave();
    AhaProofShareEligibility.resetForTest();
    ArchiveTrustReceipt.resetForTest();
    CleanSlatePromptStore.resetSessionForTest();
    CleanSlatePromptStore.seedSessionStartForTest(
      DateTime.now().subtract(const Duration(seconds: 61)),
    );
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      prefsPath: '${tempDir.path}/prefs.json',
      skipRevenueCat: true,
    );
    VisualAuditOverrides.setRecordPresentation(
      const RecordAuditPresentation(ui: RecordUiState.ready),
    );
  });

  tearDown(() async {
    await settleAppServicesForTest();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    VisualAuditOverrides.setRecordPresentation(null);
    ActivationFunnelAnalytics.resetForTest();
  });

  Future<void> pumpRecordScreen(
    WidgetTester tester, {
    RecordUiState ui = RecordUiState.ready,
  }) async {
    VisualAuditOverrides.setRecordPresentation(RecordAuditPresentation(ui: ui));
    await tester.binding.setSurfaceSize(_smallScreen);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      withAppProviderScope(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordScreen(
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> saveEntries(int count, {DateTime? baseDate}) async {
    final store = AppServices.instance.journalStore;
    for (var i = 0; i < count; i++) {
      await store.save(
        _entry(
          id: 'e$i',
          createdAt: baseDate?.add(Duration(hours: i)),
        ),
      );
    }
  }

  Future<void> scrollRecordScreen(WidgetTester tester) async {
    final scroll = find.byKey(const Key('record_screen_scroll'));
    expect(scroll, findsOneWidget);
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pumpAndSettle();
  }

  group('Record screen overflow', () {
    testWidgets('renders with 0 entries on small height', (tester) async {
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('record_screen_scroll')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders with 1 entry without second-entry nudge on small height',
      (tester) async {
        await tester.runAsync(() => saveEntries(1));
        await pumpRecordScreen(tester);
        // Second-entry nudge lives behind comparison-seed gates (>=2 entries).
        expect(find.byKey(const Key('second_entry_nudge_card')), findsNothing);
        expect(find.byKey(const Key('record_screen_scroll')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders with 6 entries and advanced save options collapsed by default',
      (tester) async {
        await tester.runAsync(() => saveEntries(6));
        await pumpRecordScreen(tester);
        expect(find.byKey(const Key('entry_options_section')), findsOneWidget);
        expect(
          find.text(EntryMemoryModeCopy.advancedSaveOptionsTitle),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('entry_memory_scope_picker')),
          findsNothing,
        );
        expect(find.byKey(const Key('entry_thread_picker')), findsNothing);
        expect(find.byKey(const Key('archive_pack_picker')), findsNothing);

        await expandAdvancedSaveOptions(tester);

        expect(
          find.byKey(const Key('entry_memory_scope_picker')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('entry_thread_picker')), findsOneWidget);
        expect(find.byKey(const Key('archive_pack_picker')), findsOneWidget);
        expect(find.byKey(const Key('entry_aboutness_picker')), findsOneWidget);
        expect(
          find.byKey(const Key('memory_surfacing_picker')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('entry options can scroll without RenderFlex overflow', (
      tester,
    ) async {
      await tester.runAsync(() => saveEntries(6));
      await pumpRecordScreen(tester);
      await scrollRecordScreen(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('record button remains reachable', (tester) async {
      await tester.runAsync(() => saveEntries(6));
      await pumpRecordScreen(tester);
      await scrollRecordScreen(tester);
      final recordActions = find.byType(CaptureEntryActions);
      await tester.ensureVisible(recordActions);
      expect(recordActions, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('save flow still works', (tester) async {
      await tester.runAsync(() => saveEntries(2));
      await pumpRecordScreen(tester);
      await scrollRecordScreen(tester);
      final recordActions = find.byType(CaptureEntryActions);
      await tester.ensureVisible(recordActions);
      final micIcon = find.descendant(
        of: recordActions,
        matching: find.byIcon(Icons.mic),
      );
      expect(micIcon, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('memory scope picker still renders', (tester) async {
      await tester.runAsync(() => saveEntries(3));
      await pumpRecordScreen(tester);
      await expandAdvancedSaveOptions(tester);
      expect(
        find.byKey(const Key('entry_memory_scope_picker')),
        findsOneWidget,
      );
    });

    testWidgets('thread picker still renders', (tester) async {
      await tester.runAsync(() => saveEntries(3));
      await pumpRecordScreen(tester);
      await expandAdvancedSaveOptions(tester);
      expect(find.byKey(const Key('entry_thread_picker')), findsOneWidget);
    });

    testWidgets('pack picker still renders', (tester) async {
      await tester.runAsync(() => saveEntries(3));
      await pumpRecordScreen(tester);
      await expandAdvancedSaveOptions(tester);
      expect(find.byKey(const Key('archive_pack_picker')), findsOneWidget);
    });

    testWidgets('entry aboutness picker still renders', (tester) async {
      await tester.runAsync(() => saveEntries(3));
      await pumpRecordScreen(tester);
      await expandAdvancedSaveOptions(tester);
      expect(find.byKey(const Key('entry_aboutness_picker')), findsOneWidget);
    });

    testWidgets('surfacing picker still renders', (tester) async {
      await tester.runAsync(() => saveEntries(3));
      await pumpRecordScreen(tester);
      await expandAdvancedSaveOptions(tester);
      expect(find.byKey(const Key('memory_surfacing_picker')), findsOneWidget);
    });

    test('topic shift prompt is eligible with seeded records', () {
      EntryThreadScopeSession.selectExistingThread(
        'thread_other',
        entryCount: 3,
      );
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: [
          _pressureRec(id: 'p1', daysAgo: 6, archiveThreadId: 'thread_work'),
          _pressureRec(id: 'p2', daysAgo: 3, archiveThreadId: 'thread_work'),
          _pressureRec(id: 'p3', daysAgo: 0, archiveThreadId: 'thread_work'),
        ],
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isTrue);
    });

    testWidgets('topic shift prompt still renders when eligible', (
      tester,
    ) async {
      EntryThreadScopeSession.selectExistingThread(
        'thread_other',
        entryCount: 3,
      );
      final decision = TopicShiftGuard.evaluate(
        entryCount: 3,
        records: [
          _pressureRec(id: 'p1', daysAgo: 6, archiveThreadId: 'thread_work'),
          _pressureRec(id: 'p2', daysAgo: 3, archiveThreadId: 'thread_work'),
          _pressureRec(id: 'p3', daysAgo: 0, archiveThreadId: 'thread_work'),
        ],
        trackAnalytics: false,
      );
      expect(decision.shouldPrompt, isTrue);

      await tester.binding.setSurfaceSize(_smallScreen);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              key: const Key('record_screen_scroll'),
              child: CleanSlatePromptCard(decision: decision, entryCount: 3),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('clean_slate_prompt_card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('post-save done state scrolls without overflow', (
      tester,
    ) async {
      await tester.runAsync(() => saveEntries(3));
      await pumpRecordScreen(tester, ui: RecordUiState.done);
      await tester.pump(const Duration(milliseconds: 400));
      await scrollRecordScreen(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'evidence context tag and share buttons stay tappable on narrow screen',
      (tester) async {
        AhaProofShareEligibility.markEligibleFromAhaUseful();
        var copied = false;

        await tester.binding.setSurfaceSize(_smallScreen);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                key: const Key('record_screen_scroll'),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    EvidenceContextTagCard(onSaveTag: (_) {}, onSkip: () {}),
                    AhaProofShareCard(
                      entryCount: 2,
                      onDismiss: () {},
                      onCopy: (_) async => copied = true,
                      onShare: (_) async {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byKey(const Key('evidence_context_tag_card')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('evidence_context_tag_work')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('evidence_context_tag_save')));
        await tester.pump();
        expect(tester.takeException(), isNull);

        await scrollRecordScreen(tester);
        final copyButton = find.byKey(const Key('aha_proof_share_copy'));
        await tester.ensureVisible(copyButton);
        await tester.tap(copyButton);
        await tester.pump();

        expect(copied, isTrue);
        expect(tester.takeException(), isNull);
        expect(ProTrustCopy.shareTextTemplate, contains('ArchiveMe'));
        expect(ProTrustCopy.shareTextTemplate, isNot(contains('VoiceMemory')));
      },
    );

    test('no private analytics content added', () {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.detailsOpened,
        source: 'record',
      );
      for (final event in _events) {
        for (final value in event.properties.values) {
          final lower = value.toString().toLowerCase();
          expect(lower, isNot(contains('private')));
          expect(lower, isNot(contains('secret transcript')));
        }
      }
    });

    test('no VoiceMemory in record overflow consumer widgets', () {
      final copy = ProTrustCopy.all.join(' ').toLowerCase();
      expect(copy, isNot(contains('voicememory')));
      for (final word in _bannedWords) {
        expect(copy, isNot(contains(word.toLowerCase())));
      }
    });
  });

  group('Record screen accessibility', () {
    Future<void> pumpAtTextScale(
      WidgetTester tester, {
      required double scale,
      RecordUiState ui = RecordUiState.ready,
    }) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(ui: ui),
      );
      await tester.binding.setSurfaceSize(_smallScreen);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: RecordScreen(
                suggestionAttributionStore: MemorySuggestionAttributionStore(),
                entitlementReader: FakeArchiveEntitlementReader(pro: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets(
      'ready state remains usable at 200% text scale with no overflow',
      (tester) async {
        await tester.runAsync(() => saveEntries(3));
        await pumpAtTextScale(tester, scale: 2);
        expect(tester.takeException(), isNull);

        await scrollRecordScreen(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'recording state remains usable at 200% text scale with no overflow',
      (tester) async {
        await pumpAtTextScale(tester, scale: 2, ui: RecordUiState.recording);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'record button exposes an accessible label from its visible text, '
      'not a bare icon-only control',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpRecordScreen(tester);
        final button = find.byKey(const Key('capture_entry_record_cta'));
        expect(button, findsOneWidget);
        expect(
          find.descendant(
            of: button,
            matching: find.bySemanticsLabel(RegExp('.+')),
          ),
          findsWidgets,
          reason:
              'the mic-icon record CTA must carry a real accessible label, '
              'not just a decorative icon',
        );
        handle.dispose();
      },
    );
  });
}