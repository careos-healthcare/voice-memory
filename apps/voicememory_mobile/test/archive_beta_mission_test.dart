import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_copy.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_copy.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gates.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_store.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/archive_beta_mission_card.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';

import 'support/memory_pressure_stores.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/archive_beta_mission/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

void main() {
  group('ArchiveBetaMissionCopy', () {
    test('copy matches beta tester onboarding brief', () {
      expect(ArchiveBetaMissionCopy.title, TesterMissionCopy.title);
      expect(ArchiveBetaMissionCopy.mission, TesterMissionCopy.mission);
      expect(ArchiveBetaMissionCopy.steps, TesterMissionCopy.steps);
      expect(
        ArchiveBetaMissionCopy.feedbackLine,
        TesterMissionCopy.feedbackQuestion,
      );
      expect(ArchiveBetaMissionCopy.startCta, 'Start with one moment');
      expect(ArchiveBetaMissionCopy.hideCta, 'Hide this');
    });
  });

  group('ArchiveBetaMissionGate', () {
    tearDown(ArchiveBetaMissionGate.resetForTest);

    test('disabled when override is false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(ArchiveBetaMissionGate.isEnabled, isFalse);
    });

    test('enabled when override is true', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(ArchiveBetaMissionGate.isEnabled, isTrue);
    });
  });

  group('ArchiveBetaMissionGates', () {
    tearDown(ArchiveBetaMissionGate.resetForTest);

    test('hidden when beta gate is off', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        ArchiveBetaMissionGates.shouldShow(
          dismissed: false,
          ui: RecordUiState.ready,
          entryCountLoaded: true,
          entryCount: 0,
          isRecording: false,
        ),
        isFalse,
      );
    });

    test('shown in beta mode before three entries', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        ArchiveBetaMissionGates.shouldShow(
          dismissed: false,
          ui: RecordUiState.ready,
          entryCountLoaded: true,
          entryCount: 2,
          isRecording: false,
        ),
        isTrue,
      );
    });

    test('hidden after dismiss or three entries', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        ArchiveBetaMissionGates.shouldShow(
          dismissed: true,
          ui: RecordUiState.ready,
          entryCountLoaded: true,
          entryCount: 0,
          isRecording: false,
        ),
        isFalse,
      );
      expect(
        ArchiveBetaMissionGates.shouldShow(
          dismissed: false,
          ui: RecordUiState.ready,
          entryCountLoaded: true,
          entryCount: 3,
          isRecording: false,
        ),
        isFalse,
      );
    });

    test('does not duplicate Save one moment or Record moment CTAs', () {
      expect(
        ArchiveBetaMissionGates.isDuplicateCaptureCtaLabel(
          VisibleArchiveProofCopy.firstUseCaptureCta,
        ),
        isTrue,
      );
      expect(
        ArchiveBetaMissionGates.isDuplicateCaptureCtaLabel(
          ConsumerUiCopy.recordMomentCta,
        ),
        isTrue,
      );
      expect(
        ArchiveBetaMissionGates.showMissionStartCta(
          policy: const RecordCtaPolicyResolution(
            state: RecordCtaPolicyState.firstUse,
            primaryLabel: VisibleArchiveProofCopy.firstUseCaptureCta,
            showMainBottomCta: true,
            action: RecordCtaAction.startRecording,
          ),
          hideCardRecordButtons: true,
          promoteMicCaptureActions: false,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveBetaMissionStore', () {
    setUp(() async {
      await AppServices.resetForTest(
        journalPath:
            '${DateTime.now().microsecondsSinceEpoch}_archive_beta_mission.json',
        prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
        skipRevenueCat: true,
      );
      await ArchiveBetaMissionStore.resetForTest();
    });

    test('dismiss persists locally', () async {
      final prefs = _MemoryPrefs();
      final store = ArchiveBetaMissionStore(prefs);
      expect(await store.loadDismissed(), isFalse);

      await store.dismiss();
      expect(await store.loadDismissed(), isTrue);
      expect(prefs.maps[ArchiveBetaMissionStore.prefsKey]?['dismissed'], isTrue);
    });
  });

  group('ArchiveBetaMissionCard widget', () {
    testWidgets('hide CTA dismisses card', (tester) async {
      final prefs = _MemoryPrefs();
      final store = ArchiveBetaMissionStore(prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveBetaMissionCard.test(
              showStartCta: true,
              store: store,
              onStart: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('archive_beta_mission_card')), findsOneWidget);
      await tester.tap(find.text(ArchiveBetaMissionCopy.hideCta));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('archive_beta_mission_card_hidden')),
        findsOneWidget,
      );
      expect(await store.loadDismissed(), isTrue);
    });

    testWidgets('omits start CTA when capture primary is already visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArchiveBetaMissionCard.test(
              showStartCta: false,
              onStart: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(ArchiveBetaMissionCopy.startCta), findsNothing);
      expect(find.text(ArchiveBetaMissionCopy.hideCta), findsOneWidget);
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_archive_beta_mission_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      await ArchiveBetaMissionStore.resetForTest();
      ArchiveBetaMissionGate.enabledOverride = true;
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      ArchiveBetaMissionGate.resetForTest();
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpEmptyRecord(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: MemoryPressureCheckInStore(),
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CaptureEntryActions).evaluate().isNotEmpty) return;
      }
    }

    testWidgets('record screen uses tester mission instead of legacy card', (
      tester,
    ) async {
      await pumpEmptyRecord(tester);

      expect(find.byKey(const Key('archive_beta_mission_card')), findsNothing);
      expect(find.byKey(const Key('tester_mission_compact_strip')), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.firstUseCaptureCta), findsOneWidget);
    });

    testWidgets('legacy card hidden when beta gate is off', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await pumpEmptyRecord(tester);

      expect(find.byKey(const Key('archive_beta_mission_card')), findsNothing);
      expect(find.byKey(const Key('tester_mission_compact_strip')), findsNothing);
    });
  });
}
