import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/first_session/first_recording_sample.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/features/recording/recording_screen.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/capture_entry_actions.dart';
import 'package:archiveme_mobile/widgets/first_session/first_recording_sample_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/memory_pressure_stores.dart';
import 'support/test_storage_sandbox.dart';

JournalEntry _entry({String id = 'e1', DateTime? createdAt}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 11, 12),
    transcript: 'A long enough transcript to count as a saved reflection.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<({String event, Map<String, Object> properties})> eventsNamed(
    String name,
  ) => captured.where((e) => e.event == name).toList();

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    FirstRecordingSample.resetForTest();
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    FirstRecordingSample.resetForTest();
  });

  group('Copy guardrails', () {
    test('copy is exact', () {
      expect(FirstRecordingSample.title, 'Use this as a starting point');
      expect(
        FirstRecordingSample.sample,
        'Something I keep coming back to is\u2026',
      );
      expect(
        FirstRecordingSample.helper,
        'Change it, ignore it, or record your own words.',
      );
      expect(FirstRecordingSample.ctaLabel, 'Use this starter');
    });

    test('no banned words or VoiceMemory in the sample copy', () {
      final copy = [
        FirstRecordingSample.title,
        FirstRecordingSample.sample,
        FirstRecordingSample.helper,
        FirstRecordingSample.ctaLabel,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'task',
        'homework',
        'must',
        'should',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnose',
        'definitely',
        'therapy',
        'treatment',
        'voicememory',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'sample copy must not contain "$banned"',
        );
      }
    });
  });

  group('Visibility rule', () {
    test('only for a completely empty archive', () {
      expect(FirstRecordingSample.shouldShow(0), isTrue);
      expect(FirstRecordingSample.shouldShow(1), isFalse);
      expect(FirstRecordingSample.shouldShow(5), isFalse);
      expect(FirstRecordingSampleCard.shouldShow(0), isTrue);
      expect(FirstRecordingSampleCard.shouldShow(1), isFalse);
    });
  });

  group('Sample card widget', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      VoidCallback? onUseStarter,
    }) async {
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstRecordingSampleCard(onUseStarter: onUseStarter ?? () {}),
          ),
        )));
      await tester.pump();
    }

    testWidgets('renders the starter sentence with exactly one CTA', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(find.text(FirstRecordingSample.title), findsOneWidget);
      expect(
        find.text('\u201c${FirstRecordingSample.sample}\u201d'),
        findsOneWidget,
      );
      expect(find.text(FirstRecordingSample.helper), findsOneWidget);
      expect(find.text(FirstRecordingSample.ctaLabel), findsOneWidget);
      // One CTA only — never a list of prompts.
      expect(
        find.descendant(
          of: find.byKey(const Key('first_recording_sample_card')),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('seen fires once per session with entry_count only', (
      tester,
    ) async {
      await pumpCard(tester);
      await pumpCard(tester); // Rebuild — seen must not repeat.
      final seen = eventsNamed(
        ActivationFunnelAnalytics.firstRecordingSampleSeen,
      );
      expect(seen, hasLength(1));
      expect(seen.single.properties, {'entry_count': 0});
    });

    testWidgets('CTA seeds the recording flow and logs the tap', (
      tester,
    ) async {
      var started = 0;
      await pumpCard(tester, onUseStarter: () => started++);

      await tester.tap(find.byKey(const Key('first_recording_sample_cta')));
      expect(started, 1);
      expect(FirstRecordingSample.startedFromSampleThisSession, isTrue);

      final tapped = eventsNamed(
        ActivationFunnelAnalytics.firstRecordingSampleTapped,
      );
      expect(tapped, hasLength(1));
      expect(tapped.single.properties, {'entry_count': 0});
    });

    testWidgets('no private content in any sample payload', (tester) async {
      await pumpCard(tester);
      await tester.tap(find.byKey(const Key('first_recording_sample_cta')));

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(
          e.properties.keys.toSet().difference(
            ActivationFunnelAnalytics.allowedPropertyKeys,
          ),
          isEmpty,
        );
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        expect(flat, isNot(contains('coming back to')));
        expect(flat, isNot(contains('voicememory')));
      }
    });
  });

  group('Saved attribution', () {
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(journalPath: sandbox.journalPath);
    });

    tearDown(() => sandbox.dispose());

    test(
      'saved fires only when the first save followed the sample CTA',
      () async {
        // No CTA tap: the first save carries no sample attribution.
        await AppServices.instance.journalStore.save(_entry());
        expect(
          eventsNamed(ActivationFunnelAnalytics.firstRecordingSampleSaved),
          isEmpty,
        );
      },
    );

    test('saved fires when the starter seeded the first recording', () async {
      FirstRecordingSample.startedFromSampleThisSession = true;
      await AppServices.instance.journalStore.save(_entry());

      final saved = eventsNamed(
        ActivationFunnelAnalytics.firstRecordingSampleSaved,
      );
      expect(saved, hasLength(1));
      expect(saved.single.properties, {'entry_count': 1});
      // Flag cleared — later saves never re-attribute.
      expect(FirstRecordingSample.startedFromSampleThisSession, isFalse);
    });

    test('no saved event for a later (non-first) save', () async {
      await AppServices.instance.journalStore.save(_entry(id: 'first'));
      FirstRecordingSample.startedFromSampleThisSession = true;
      await AppServices.instance.journalStore.save(
        _entry(id: 'second', createdAt: DateTime(2026, 6, 12, 12)),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstRecordingSampleSaved),
        isEmpty,
      );
    });
  });

  group('Record screen integration', () {
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(journalPath: sandbox.journalPath);
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() => sandbox.dispose());

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpRecordScreen(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('legacy sample card hidden on Record under beta gates', (
      tester,
    ) async {
      await pumpRecordScreen(tester);
      expect(
        find.byKey(const Key('first_recording_sample_card')),
        findsNothing,
      );
      expect(find.byKey(const Key('record_screen_scroll')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides after the first save', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry());
      });
      await pumpRecordScreen(tester);
      expect(
        find.byKey(const Key('first_recording_sample_card')),
        findsNothing,
      );
      expect(find.text(FirstRecordingSample.title), findsNothing);
    });

    testWidgets(
      'record screen keeps standard capture path without legacy sample',
      (tester) async {
        await pumpRecordScreen(tester);
        expect(find.byType(CaptureEntryActions), findsOneWidget);
        expect(
          find.byKey(const Key('first_recording_sample_card')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('normal recording path stays unchanged', (tester) async {
      await pumpRecordScreen(tester);
      // The standard record entry actions render alongside the sample.
      expect(find.byType(CaptureEntryActions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}