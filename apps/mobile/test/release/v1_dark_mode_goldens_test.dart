import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_dashboard_scroll_view.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/features/archive_changes/archive_changes_adapter.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_screen.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/screens/entry_detail_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/moment_save_receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../capture_flow/capture_screen_overflow_test.dart';

const _surface = Size(390, 844);

JournalEntry _entry(String id, String transcript) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 14, 30),
  transcript: transcript,
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 2.0]) {
      final label = '${brightness.name}_x$scale';

      testWidgets('record idle $label', (tester) async {
        await _pump(
          tester,
          brightness: brightness,
          scale: scale,
          child: CaptureScreen(
            initialInputMode: CaptureInputMode.voice,
            routineKindOverride: JournalRoutineKind.morning,
            dependencies: captureFlowGoldenDependencies(),
          ),
        );
        await _expectGolden(tester, 'record_idle_$label');
      });

      testWidgets('recording $label', (tester) async {
        await _pump(
          tester,
          brightness: brightness,
          scale: scale,
          child: CaptureScreen(
            initialInputMode: CaptureInputMode.voice,
            routineKindOverride: JournalRoutineKind.morning,
            dependencies: captureFlowGoldenDependencies(),
          ),
        );
        await tester.ensureVisible(find.byKey(const Key('capture_start_voice')));
        await tester.tap(find.byKey(const Key('capture_start_voice')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _expectGolden(tester, 'recording_$label');
      });

      testWidgets('receipt $label', (tester) async {
        await _pump(
          tester,
          brightness: brightness,
          scale: scale,
          child: MomentSaveReceiptCard(
            entry: _entry('e1', 'I said yes again today.'),
            entryCount: 1,
            onRecordAnother: () {},
            onViewArchive: () {},
            onCorrectText: () {},
          ),
        );
        await _expectGolden(tester, 'receipt_$label');
      });

      testWidgets('archive empty $label', (tester) async {
        await _pumpArchive(tester, brightness: brightness, scale: scale);
        await _expectGolden(tester, 'archive_empty_$label');
      });

      testWidgets('archive 3 entries $label', (tester) async {
        await _pumpArchive(
          tester,
          brightness: brightness,
          scale: scale,
          entries: [
            _entry('a', 'First saved moment about the meeting.'),
            _entry('b', 'Second saved moment about the deadline.'),
            _entry('c', 'Third saved moment about coming back tomorrow.'),
          ],
        );
        await _expectGolden(tester, 'archive_three_$label');
      });

      testWidgets('entry detail $label', (tester) async {
        await _pump(
          tester,
          brightness: brightness,
          scale: scale,
          child: EntryDetailScreen(
            entryId: 'detail',
            previewEntry: _entry(
              'detail',
              'A long enough transcript for the entry detail golden.',
            ),
          ),
        );
        await tester.pump();
        await _expectGolden(tester, 'entry_detail_$label');
      });
    }
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required double scale,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _surface;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final theme = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      darkTheme: theme,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _pumpArchive(
  WidgetTester tester, {
  required Brightness brightness,
  required double scale,
  List<JournalEntry> entries = const [],
}) {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  return _pump(
    tester,
    brightness: brightness,
    scale: scale,
    child: ArchiveDashboardScrollView(
      controller: controller,
      feed: ArchiveFeedState(
        loadState: ArchiveBeliefLoadState.loaded,
        entries: entries,
        totalCount: entries.length,
        archiveTotalCount: entries.length,
      ),
      loadState: ArchiveBeliefLoadState.loaded,
      visibleEntries: entries,
      showChangesUnavailable: false,
      onRefresh: () async {},
      onEntryTap: (_) {},
      onQueryChanged: (_) {},
      onCapture: () {},
      previewChangesSnapshot: const ArchiveChangesSnapshot(
        entries: [],
        timeline: [],
        eligible: false,
      ),
    ),
  );
}

Future<void> _expectGolden(WidgetTester tester, String name) {
  return expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}
