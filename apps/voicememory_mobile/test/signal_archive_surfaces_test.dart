import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/post_save_insight/selected_signal_model.dart';
import 'package:voicememory_mobile/features/post_save_insight/signal_feedback_coordinator.dart';
import 'package:voicememory_mobile/features/post_save_insight/signal_feedback_model.dart';
import 'package:voicememory_mobile/features/post_save_insight/signal_feedback_store.dart';
import 'package:voicememory_mobile/features/signal_archive/signal_archive_snapshot.dart';
import 'package:voicememory_mobile/features/signal_archive/signal_corrections_engine.dart';
import 'package:voicememory_mobile/features/signal_archive/signal_evidence_engine.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/signal_detail_screen.dart';
import 'package:voicememory_mobile/screens/signal_evidence_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/signal/archive_home_dashboard.dart';
import 'package:voicememory_mobile/widgets/signal/archive_watching_card.dart';
import 'package:voicememory_mobile/widgets/signal/signal_corrections_card.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_signal_archive_journal_$stamp.json',
    prefsPath: '/tmp/vm_signal_archive_prefs_$stamp.json',
  );
}

SelectedSignalRecord _sampleSignal() {
  return SelectedSignalRecord(
    id: 'sig1',
    title: 'Saying yes before checking capacity',
    categoryId: 'pressure',
    strengthLabel: 'Getting clearer',
    nextPrompt: 'When did you last say yes while already stretched?',
    savedAt: DateTime(2026, 6, 2),
    mightMean: 'You may be agreeing before you have room.',
    wouldConfirm: 'Another moment where you say yes while already full.',
    wouldContradict: 'If you pause and feel ease when you say no.',
    evidenceUsed: 'You mentioned pressure and saying yes.',
    evidenceChips: const ['pressure', 'yes'],
  );
}

SignalArchiveSnapshot _snapshot({SelectedSignalRecord? signal}) {
  final selected = signal;
  return SignalArchiveSnapshot(
    selectedSignal: selected,
    evidenceTrail: const SignalEvidenceEngine().build(
      signal: selected,
      entries: const [],
    ),
    corrections: const SignalCorrectionsEngine().build(
      feedback: [],
      currentSignal: null,
    ),
    hypothesis: null,
    reflectionCount: selected == null ? 0 : 1,
  );
}

Widget _routerShell(Widget child) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => child),
        GoRoute(
          path: '/record',
          builder: (_, __) => const Scaffold(body: Text('Record tab')),
        ),
        GoRoute(
          path: '/signal-detail',
          builder: (_, __) => const SignalDetailScreen(),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('signal detail renders selected signal', (tester) async {
    final snapshot = _snapshot(signal: _sampleSignal());

    await tester.pumpWidget(
      MaterialApp(home: SignalDetailScreen(initialSnapshot: snapshot)),
    );
    await tester.pump();

    expect(find.text('Saying yes before checking capacity'), findsOneWidget);
    expect(find.text('Getting clearer'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.signalDetailThinksMayBe), findsOneWidget);
  });

  testWidgets('signal detail empty state renders safely', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SignalDetailScreen(initialSnapshot: _snapshot())),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.signalDetailEmptyTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.signalDetailRecordMoment), findsOneWidget);
  });

  testWidgets('record next evidence CTA routes to record', (tester) async {
    final snapshot = _snapshot(signal: _sampleSignal());

    await tester.pumpWidget(
      _routerShell(SignalDetailScreen(initialSnapshot: snapshot)),
    );
    await tester.pump();

    final cta = find.text(ConsumerUiCopy.postSaveInsightRecordNextEvidence);
    await tester.scrollUntilVisible(cta, 300);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(find.text('Record tab'), findsOneWidget);
  });

  testWidgets('mark not me button is available on signal detail', (
    tester,
  ) async {
    final snapshot = _snapshot(signal: _sampleSignal());

    await tester.pumpWidget(
      MaterialApp(home: SignalDetailScreen(initialSnapshot: snapshot)),
    );
    await tester.pump();

    final markNotMe = find.text(ConsumerUiCopy.signalDetailMarkNotMe);
    await tester.scrollUntilVisible(markNotMe, 300);
    expect(markNotMe, findsOneWidget);
  });

  testWidgets('evidence trail supports low-evidence state', (tester) async {
    final snapshot = _snapshot(signal: _sampleSignal());

    await tester.pumpWidget(
      MaterialApp(home: SignalEvidenceScreen(initialSnapshot: snapshot)),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.signalEvidenceNeedsMore), findsOneWidget);
  });

  testWidgets('archive watching card shows active signal', (tester) async {
    final snapshot = _snapshot(signal: _sampleSignal());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ArchiveWatchingCard(snapshot: snapshot)),
      ),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.archiveWatchingTitle), findsOneWidget);
    expect(find.text('Saying yes before checking capacity'), findsOneWidget);
  });

  testWidgets('archive watching empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ArchiveWatchingCard(snapshot: _snapshot())),
      ),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.archiveWatchingEmpty), findsOneWidget);
  });

  testWidgets('corrections card shows rejected and selected', (tester) async {
    const engine = SignalCorrectionsEngine();
    final view = engine.build(feedback: const [], currentSignal: null);
    expect(view.hasCorrections, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SignalCorrectionsCard(corrections: view)),
      ),
    );
    expect(find.text(ConsumerUiCopy.signalCorrectionsTitle), findsNothing);

    final withCorrections = engine.build(
      feedback: [
        PostSaveSignalFeedback(
          id: '1',
          signalId: 'old',
          signalTitle: 'Old read that was not me',
          action: PostSaveSignalAction.rejected,
          createdAt: DateTime(2026, 6, 1),
        ),
      ],
      currentSignal: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignalCorrectionsCard(corrections: withCorrections),
        ),
      ),
    );
    expect(find.text(ConsumerUiCopy.signalCorrectionsTitle), findsOneWidget);
    expect(find.text('Old read that was not me'), findsOneWidget);
  });

  testWidgets('archive dashboard shows quick links', (tester) async {
    final snapshot = _snapshot(signal: _sampleSignal());

    await tester.pumpWidget(
      MaterialApp(home: ArchiveHomeDashboard(snapshot: snapshot)),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.archiveHomeTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.archiveHomeOpenDetail), findsOneWidget);
    expect(find.text(ConsumerUiCopy.archiveHomeOpenTrail), findsOneWidget);
    expect(find.text(ConsumerUiCopy.archiveHomeRecordEvidence), findsOneWidget);
  });

  test('consumer copy avoids VoiceMemory branding', () {
    expect(ConsumerUiCopy.archiveHomeTitle, isNot(contains('VoiceMemory')));
  });

  test('not me feedback persists via coordinator', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await SignalFeedbackCoordinator.track(
      action: PostSaveSignalAction.rejected,
      signalId: 'sig1',
      signalTitle: 'Rejected read',
      categoryId: 'pressure',
    );
    final rows = await SignalFeedbackStore.instance().loadAll();
    expect(rows.any((r) => r.action == PostSaveSignalAction.rejected), isTrue);
  });
}
