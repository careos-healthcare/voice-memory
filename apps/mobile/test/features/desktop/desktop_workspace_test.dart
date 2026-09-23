import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/features/attachments/local_ocr_processor.dart';
import 'package:archiveme_mobile/features/desktop/desktop_drop_ingestion.dart';
import 'package:archiveme_mobile/features/desktop/desktop_master_detail_layout.dart';
import 'package:archiveme_mobile/features/desktop/desktop_shortcut_manager.dart';
import 'package:archiveme_mobile/features/desktop/desktop_workspace.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const moments = [
    DesktopMoment(
      id: 'moment-1',
      title: 'Morning note',
      transcript: 'Quiet start',
    ),
    DesktopMoment(
      id: 'moment-2',
      title: 'Went for a 5km run',
      transcript: 'Went for a 5km run',
      entityNames: ['5km run'],
      hasAudio: true,
    ),
  ];

  testWidgets('wide windows keep three columns and the selected moment', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final playback = DesktopPlaybackController();
    addTearDown(playback.dispose);
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopArchiveColumns(
          moments: moments,
          playback: playback,
          destinations: const [
            DesktopNavDestination(
              label: 'Record',
              selected: false,
              onTap: _noop,
            ),
            DesktopNavDestination(
              label: 'Archive',
              selected: true,
              onTap: _noop,
            ),
            DesktopNavDestination(
              label: 'Account',
              selected: false,
              onTap: _noop,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('desktop_nav_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('desktop_moment_stream')), findsOneWidget);
    expect(find.byKey(const Key('desktop_entity_inspector')), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('desktop_moment_moment-2')));
    await tester.pump();
    expect(find.byKey(const Key('desktop_entity_5km run')), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.byKey(const Key('desktop_audio_player')));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pump();
    expect(find.byKey(const Key('desktop_nav_sidebar')), findsNothing);
    expect(
      find.byKey(const Key('desktop_entity_inspector'), skipOffstage: false),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(const Size(841, 900));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    expect(find.byKey(const Key('desktop_entity_5km run')), findsOneWidget);
  });

  testWidgets('side pane state survives a narrow resize', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    await tester.pumpWidget(
      const MaterialApp(
        home: DesktopMasterDetailLayout(
          navigation: Text('Nav'),
          timeline: Text('Stream'),
          inspector: _Tick(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('ticks 0'));
    await tester.pump();
    expect(find.text('ticks 1'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(840, 800));
    await tester.pump();
    expect(find.text('ticks 1'), findsNothing);

    await tester.binding.setSurfaceSize(const Size(1100, 800));
    await tester.pump();
    expect(find.text('ticks 1'), findsOneWidget);
  });

  testWidgets('hotkeys record, focus search, export, and toggle playback', (
    tester,
  ) async {
    final search = FocusNode();
    final window = FocusNode();
    addTearDown(search.dispose);
    addTearDown(window.dispose);
    var recordings = 0;
    var exports = 0;
    final playback = DesktopPlaybackController()..select('moment-2', hasAudio: true);
    addTearDown(playback.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopShortcutManager(
            searchFocus: search,
            onNewRecording: () => recordings += 1,
            onUniversalExport: () => exports += 1,
            onTogglePlayback: playback.toggle,
            child: Column(
              children: [
                TextField(focusNode: search),
                const TextField(key: Key('notes_field')),
                Focus(focusNode: window, child: const Text('Window')),
                AnimatedBuilder(
                  animation: playback,
                  builder: (context, _) {
                    return Text(playback.playing ? 'playing' : 'stopped');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
    await tester.pump();
    expect(recordings, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(search.hasFocus, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyE);
    await tester.pumpAndSettle();
    expect(exports, 1);
    expect(find.byKey(const Key('universal_export_dialog')), findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notes_field')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('stopped'), findsOneWidget);

    window.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('playing'), findsOneWidget);
  });

  testWidgets('the workspace opens on a wide surface', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    var recordings = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWorkspace(
          moments: moments,
          enableFileDrop: false,
          onNewRecording: () => recordings += 1,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('desktop_nav_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('semantic_search_field')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
    await tester.pump();
    expect(recordings, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  });

  test('dropped audio, pictures, and PDFs become moments', () async {
    final directory = await Directory.systemTemp.createTemp('desktop-drop');
    final app = await openTestAppSqliteDatabase(
      filePath: '${directory.path}/archive.db',
    );
    addTearDown(() async {
      await app.close();
      AppSqliteDatabase.resetForTest();
    });
    final ingestion = DesktopFileIngestion(
      clock: () => DateTime(2026, 9, 23),
      ocr: LocalOcrProcessor(
        photosEnabled: true,
        recognize: (_) async => const OcrDocument(
          text: 'Met Ada',
          blocks: [],
        ),
      ),
      transcribe: (bytes, name) async {
        if (name.endsWith('.wav')) return 'Went for a 5km run';
        return '';
      },
    );

    final created = await ingestion.ingest(
      database: app.database,
      files: [
        DesktopDroppedFile(name: 'run.wav', bytes: Uint8List.fromList([1])),
        DesktopDroppedFile(name: 'page.png', bytes: Uint8List.fromList([2])),
        DesktopDroppedFile(
          name: 'notes.pdf',
          bytes: latin1.encode('(Meeting notes)'),
        ),
        DesktopDroppedFile(name: 'song.mp3', bytes: Uint8List.fromList([3])),
        DesktopDroppedFile(name: 'skip.txt', bytes: Uint8List(0)),
      ],
    );

    expect(created.map((moment) => moment.kind), [
      DesktopDropKind.audio,
      DesktopDropKind.image,
      DesktopDropKind.pdf,
      DesktopDropKind.audio,
    ]);
    expect(created[0].transcript, 'Went for a 5km run');
    expect(created[1].transcript, 'Met Ada');
    expect(created[1].entityIds, isNotEmpty);
    expect(created[2].transcript, 'Meeting notes');
    expect(created[3].transcript, 'song.mp3');

    final rows = await app.database.query(
      'journal_entries',
      orderBy: 'id ASC',
    );
    expect(rows, hasLength(4));
  });
}

void _noop() {}

class _Tick extends StatefulWidget {
  const _Tick();

  @override
  State<_Tick> createState() => _TickState();
}

class _TickState extends State<_Tick> {
  int ticks = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => ticks += 1),
      child: Text('ticks $ticks'),
    );
  }
}
