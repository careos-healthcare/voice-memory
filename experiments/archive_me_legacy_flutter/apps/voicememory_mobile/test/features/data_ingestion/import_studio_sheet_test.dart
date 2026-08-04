import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_models.dart';
import 'package:voicememory_mobile/features/autonomous_muse/legacy_sweep_orchestrator.dart';
import 'package:voicememory_mobile/features/autonomous_muse/thematic_triage.dart';
import 'package:voicememory_mobile/features/data_ingestion/graph_ingestion_pipeline.dart';
import 'package:voicememory_mobile/features/data_ingestion/ui/import_studio_sheet.dart';

void main() {
  testWidgets('shows progress and triggers folder selection', (tester) async {
    const selectedPath = '/tmp/example-markdown-vault';
    final pipeline = _FakeIngestionController();
    var pickerCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportStudioSheet(
            pipeline: pipeline,
            legacySweepController: const _SweepController(),
            directoryPicker: () async {
              pickerCalls++;
              return selectedPath;
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('legacy-import-progress')), findsOneWidget);
    expect(
      find.byKey(const Key('legacy-import-open-muse-digest')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('legacy-import-pick-folder')));
    await tester.pump();
    expect(pickerCalls, 1);
    expect(find.text(selectedPath), findsOneWidget);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('legacy-import-progress')),
    );
    expect(indicator.value, 0);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('legacy-import-start')))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

final class _SweepController implements LegacySweepController {
  const _SweepController();

  @override
  LegacySweepProgress get currentProgress => const LegacySweepProgress.idle();

  @override
  Stream<LegacySweepProgress> get progress => const Stream.empty();

  @override
  List<LegacyBridgeSuggestion> pendingSuggestions() => const [];

  @override
  List<ThematicDeck> thematicDecks({bool includeDeepConnections = false}) =>
      const [];

  @override
  int backlogCount({bool includeDeepConnections = false}) => 0;

  @override
  Future<void> accept(String suggestionId) async {}

  @override
  Future<void> reject(String suggestionId) async {}

  @override
  Future<void> defer(String suggestionId) async {}
}

final class _FakeIngestionController implements GraphIngestionController {
  @override
  Stream<GraphIngestionProgress> get progress => const Stream.empty();

  @override
  void cancel() {}

  @override
  Future<GraphIngestionResult> ingestDirectory(Directory directory) async =>
      const GraphIngestionResult(
        parsedNotes: 1,
        insertedNotes: 1,
        skippedNotes: 0,
        insertedChunks: 1,
        insertedEdges: 0,
        elapsed: Duration.zero,
      );
}
