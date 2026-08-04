import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

import 'memory_pressure_stores.dart';
import 'widget_test_pump.dart';

/// Shared Record screen pump/setup for widget placement tests.
class RecordScreenTestHarness {
  RecordScreenTestHarness._();

  static Directory? _tempDir;

  static Future<void> setUp({
    Size surfaceSize = const Size(390, 844),
    RecordUiState ui = RecordUiState.ready,
    bool skipRevenueCat = true,
  }) async {
    _tempDir = Directory.systemTemp.createTempSync('record_screen_test_');
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest((_, _) {});
    await AppServices.resetForTest(
      journalPath: '${_tempDir!.path}/journal.json',
      prefsPath: '${_tempDir!.path}/prefs.json',
      skipRevenueCat: skipRevenueCat,
    );
    VisualAuditOverrides.setRecordPresentation(RecordAuditPresentation(ui: ui));
  }

  static Future<void> tearDown() async {
    VisualAuditOverrides.setRecordPresentation(null);
    ActivationFunnelAnalytics.resetForTest();
    await AppServices.disposeForTest();
    final dir = _tempDir;
    _tempDir = null;
    if (dir != null && dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<void> saveEntries(List<JournalEntry> entries) async {
    final store = AppServices.instance.journalStore;
    for (final entry in entries) {
      await store.save(entry);
    }
  }

  static Future<void> pumpRecordScreen(
    WidgetTester tester, {
    RecordUiState ui = RecordUiState.ready,
    Size surfaceSize = const Size(390, 844),
    bool pro = false,
  }) async {
    VisualAuditOverrides.setRecordPresentation(RecordAuditPresentation(ui: ui));
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RecordScreen(
            suggestionAttributionStore: MemorySuggestionAttributionStore(),
            entitlementReader: FakeArchiveEntitlementReader(pro: pro),
          ),
        ),
      ),
    );
    await pumpUntilFound(
      tester,
      find.byKey(const Key('capture_entry_record_cta')),
    );
  }

  static Future<void> scrollRecordScreen(WidgetTester tester) async {
    final scroll = find.byKey(const Key('record_screen_scroll'));
    expect(scroll, findsOneWidget);
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
  }
}
