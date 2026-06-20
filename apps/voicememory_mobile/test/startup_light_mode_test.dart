import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/screens/archive_belief_screen.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/startup/startup_light_mode.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/main_shell.dart';

import 'support/memory_pressure_stores.dart';

class _CapturedEvent {
  const _CapturedEvent(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_CapturedEvent> _events = [];

const _heavyStartupEvents = {
  ActivationFunnelAnalytics.memoryGovernanceChecked,
  ActivationFunnelAnalytics.archiveRetrievalScored,
  ActivationFunnelAnalytics.archiveRetrievalUsed,
  ActivationFunnelAnalytics.beliefDistanceSeen,
  ActivationFunnelAnalytics.ahaMomentSeen,
  ActivationFunnelAnalytics.ahaMomentCandidateFound,
  ActivationFunnelAnalytics.topicShiftChecked,
  ActivationFunnelAnalytics.day7ContinuitySeen,
  ActivationFunnelAnalytics.weeklyThreadReviewSeen,
};

JournalEntry _transcriptEntry({
  required String id,
  DateTime? createdAt,
  String? transcript,
  Reflection? reflection,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
    transcript:
        transcript ??
        'A long enough transcript to count as a saved reflection.',
    durationSeconds: 30,
    localAudioPath: '/tmp/$id.m4a',
    syncStatus: SyncStatus.pendingUpload,
    reflection:
        reflection ??
        const Reflection(
          mood: 'thoughtful',
          emotionalIntensity: 2,
          recurringThemes: ['work'],
          exactLanguagePattern: 'pattern',
          concreteObservation: 'Work pressure showed up again today.',
          repeatedSignal: 'signal',
        ),
  );
}

JournalEntry _missingAnalysisEntry({required String id}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 10, 9),
    transcript: _transcriptEntry(id: id).transcript,
    durationSeconds: 24,
    localAudioPath: '/tmp/$id.m4a',
    syncStatus: SyncStatus.pendingUpload,
    reflection: const Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

Future<void> _resetServices() async {
  final dir = Directory.systemTemp.createTempSync('vm_startup_light_');
  await AppServices.resetForTest(
    journalPath: '${dir.path}/journal.json',
    prefsPath: '${dir.path}/prefs.json',
    skipRevenueCat: true,
  );
  await AppServices.instance.prefs.setOnboardingCompleted(true);
  onboardingGate.markComplete();
}

Future<void> _seedEntries(int count, {bool missingAnalysis = false}) async {
  for (var i = 0; i < count; i++) {
    await AppServices.instance.journalStore.save(
      missingAnalysis
          ? _missingAnalysisEntry(id: 'e$i')
          : _transcriptEntry(id: 'e$i', createdAt: DateTime(2026, 6, 1 + i, 12)),
    );
  }
}

Future<void> _pumpStartupShell(
  WidgetTester tester, {
  required int entryCount,
  bool missingAnalysis = false,
  bool includePatternsScreen = false,
}) async {
  await tester.runAsync(() async {
    await _seedEntries(entryCount, missingAnalysis: missingAnalysis);
  });
  await tester.binding.setSurfaceSize(const Size(390, 2800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _startupShellRouter(
        includePatternsScreen: includePatternsScreen,
      ),
    ),
  );
}

GoRouter _startupShellRouter({bool includePatternsScreen = false}) {
  return GoRouter(
    initialLocation: '/record',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/archive-belief',
                builder: (context, state) => includePatternsScreen
                    ? const ArchiveBeliefScreen()
                    : const Scaffold(
                        body: Center(
                          child: Text('PATTERNS_TAB_PLACEHOLDER'),
                        ),
                      ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/record',
                builder: (context, state) => RecordScreen(
                  pressureCheckInStore: MemoryPressureCheckInStore(
                    [
                      PressureCheckInRecord(
                        entryId: 'e0',
                        createdAt: DateTime(2026, 6, 8, 12),
                        optionId: 'could_not_stop',
                        contextIds: const ['work'],
                        fear: 'The deadline slipping again',
                        transcript: 'pressure moment',
                      ),
                      PressureCheckInRecord(
                        entryId: 'e1',
                        createdAt: DateTime(2026, 6, 9, 12),
                        optionId: 'could_not_stop',
                        contextIds: const ['work'],
                        fear: 'Could not stop checking messages',
                        transcript: 'pressure moment',
                      ),
                      PressureCheckInRecord(
                        entryId: 'e2',
                        createdAt: DateTime(2026, 6, 10, 12),
                        optionId: 'could_not_stop',
                        contextIds: const ['work', 'evening'],
                        fear: 'Same work decision came back',
                        transcript: 'pressure moment',
                      ),
                    ],
                  ),
                  entitlementReader: FakeArchiveEntitlementReader(pro: false),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

List<_CapturedEvent> _heavyEvents() =>
    _events.where((e) => _heavyStartupEvents.contains(e.name)).toList();

void main() {
  setUp(() async {
    StartupLightMode.resetForTest();
    StartupLightMode.setEnabledForTest(true);
    ActivationFunnelAnalytics.resetForTest();
    _events.clear();
    ActivationFunnelAnalytics.captureForTest((event, properties) {
      _events.add(_CapturedEvent(event, properties));
    });
    await _resetServices();
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    StartupLightMode.resetForTest();
  });

  group('StartupLightMode cold boot', () {
    testWidgets('boots with six transcript entries on Record tab', (
      tester,
    ) async {
      await _pumpStartupShell(tester, entryCount: 6);
      await tester.pump();

      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
    });

    testWidgets('boots when analysis fields are missing', (tester) async {
      await _pumpStartupShell(
        tester,
        entryCount: 6,
        missingAnalysis: true,
      );
      await tester.pump();

      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
    });

    testWidgets('boots when billing is signed out', (tester) async {
      await _pumpStartupShell(tester, entryCount: 6);

      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
      expect(StartupLightMode.isBillingLoadAllowedForTest, isFalse);
    });

    testWidgets('Record tab renders before archive engines run', (
      tester,
    ) async {
      await _pumpStartupShell(tester, entryCount: 6);

      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
      expect(_heavyEvents(), isEmpty);
      expect(StartupLightMode.isUiStableForTest, isFalse);

      await tester.pump();

      expect(StartupLightMode.isUiStableForTest, isTrue);
      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
    });

    testWidgets('Record tab with 12 entries skips archive engines until Patterns', (
      tester,
    ) async {
      await _pumpStartupShell(
        tester,
        entryCount: 12,
        includePatternsScreen: true,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(RecordScreenFramingCopy.title), findsOneWidget);
      expect(_heavyEvents(), isEmpty);
      expect(StartupLightMode.areArchiveEnginesAllowedForTest, isFalse);

      await tester.tap(find.text(ConsumerUiCopy.patternsTabLabel));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(StartupLightMode.areArchiveEnginesAllowedForTest, isTrue);
    });

    testWidgets('Patterns tab opens when tapped', (tester) async {
      await _pumpStartupShell(
        tester,
        entryCount: 6,
        includePatternsScreen: true,
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text(ConsumerUiCopy.patternsTabLabel));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text(ConsumerUiCopy.patternsTabLabel), findsWidgets);
    });

    testWidgets('Account tab opens when tapped', (tester) async {
      await _pumpStartupShell(tester, entryCount: 6);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Account'), findsWidgets);
      expect(StartupLightMode.isBillingLoadAllowedForTest, isTrue);
    });
  });
}
