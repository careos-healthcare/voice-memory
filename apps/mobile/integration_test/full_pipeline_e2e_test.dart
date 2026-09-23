import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/benchmark_seeder_isolate.dart';
import 'package:archiveme_mobile/core/vectors/int8_quantizer.dart';
import 'package:archiveme_mobile/features/onboarding/presentation/conversational_onboarding_screen.dart';
import 'package:archiveme_mobile/features/onboarding/providers/onboarding_provider.dart';
import 'package:archiveme_mobile/features/search/rag_search_service.dart';
import 'package:archiveme_mobile/features/search/vector_search_service.dart';
import 'package:archiveme_mobile/features/voice/presentation/dictation_mic_bar.dart';
import 'package:archiveme_mobile/models/ambient_context.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/markdown_export_service.dart';
import 'package:archiveme_mobile/widgets/archive/ambient_context_pills.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

/// End-to-end pass for onboarding, a voice entry, Int8 search, and Obsidian.
///
/// ```sh
/// flutter test integration_test/full_pipeline_e2e_test.dart
/// ```
///
/// On a simulator or device, pass `-d <device-id>`.

const _voiceTranscript = 'I felt calm and hopeful during onboarding.';
const _ragQuery = 'How did I feel during onboarding?';
const _ambientLabel = '📍 London • ⛅ 18°C • 🚶 4,200 steps';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding, voice, ambient, Int8 search, and Obsidian sync', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('pipeline-e2e');
    final vault = Directory('${directory.path}/obsidian-vault')..createSync();
    final database = await openDatabase(
      '${directory.path}/pipeline.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
      CREATE TABLE pipeline_entries (
        id TEXT PRIMARY KEY,
        transcript TEXT NOT NULL,
        embedding BLOB NOT NULL,
        alpha REAL NOT NULL
      )
    ''');
      },
    );
    final store = _SqliteInt8ChunkStore(database);
    final speech = _SpeechSource();
    final dictation = _ScriptedDictation(_voiceTranscript);
    final session = OnboardingSession(
      speech: speech.stream,
      store: MemoryOnboardingCompletionStore(),
      pace: null,
      markGateComplete: () {},
      idFactory: _ids(),
    );
    addTearDown(() async {
      session.dispose();
      speech.close();
      dictation.close();
      await database.close();
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final harnessKey = GlobalKey<_PipelineHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _PipelineHarness(
          key: harnessKey,
          session: session,
          dictation: dictation,
          store: store,
          vaultPath: vault.path,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('onboarding_prompt')), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    speech.add('Something hopeful is top of mind right now.');
    await tester.pump();
    speech.add('I would like to feel calm at the end of each day.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding_orb')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harnessKey.currentState!.phase, _PipelinePhase.home);
    expect(find.text('Home'), findsOneWidget);
    expect(session.baseline, isNotNull);
    expect(session.baseline!.isOnboardingBaseline, isTrue);

    await tester.tap(find.byKey(const Key('dictation_mic_button')));
    await tester.pump();
    expect(find.textContaining('felt calm and hopeful'), findsOneWidget);
    expect(find.text(_ambientLabel), findsOneWidget);

    await tester.tap(find.byKey(const Key('dictation_mic_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pipeline_save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final saved = harnessKey.currentState!;
    expect(saved.phase, _PipelinePhase.saved);
    expect(saved.voiceEntry, isNotNull);
    expect(saved.voiceEntry!.transcript, _voiceTranscript);
    expect(saved.voiceEntry!.display.ambientContext?.pillText, _ambientLabel);

    final indexed = await database.rawQuery(
      'SELECT embedding, alpha FROM pipeline_entries WHERE id = ?',
      [saved.voiceEntry!.id],
    );
    expect(indexed, hasLength(1));
    final codes = _int8FromBlob(indexed.first['embedding']);
    expect(codes.length, int8EmbeddingBytes);
    expect(codes.lengthInBytes, 384);
    expect(indexed.first['alpha'], greaterThan(0));

    await tester.tap(find.byKey(const Key('pipeline_open_chat')));
    await tester.pump();
    expect(find.text('Chat with Your Past'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('chat_query')), _ragQuery);
    await tester.tap(find.byKey(const Key('chat_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final searched = harnessKey.currentState!;
    expect(searched.phase, _PipelinePhase.searched);
    final answer = searched.answer!;
    expect(answer.citations, isNotEmpty);
    expect(answer.citations.first.entryId, saved.voiceEntry!.id);
    expect(answer.citations.first.similarity, greaterThan(0.95));
    expect(find.textContaining('felt calm and hopeful'), findsWidgets);

    await tester.tap(find.byKey(const Key('obsidian_sync')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harnessKey.currentState!.phase, _PipelinePhase.synced);
    final notes = vault.listSync().whereType<File>().toList();
    expect(notes, hasLength(1));
    expect(notes.single.path, endsWith('.md'));
    final markdown = notes.single.readAsStringSync();
    expect(markdown, startsWith('---\n'));
    expect(markdown, contains('date: '));
    expect(markdown, contains('tags:'));
    expect(markdown, contains('mood: '));
    expect(markdown, contains('ambient_locality: London'));
    expect(markdown, contains('ambient_weather: 18°C'));
    expect(markdown, contains('ambient_steps: 4200'));
    expect(markdown, contains(_voiceTranscript));
    expect(markdown, contains('\n---\n'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

enum _PipelinePhase { onboarding, home, saved, chat, searched, synced }

class _PipelineHarness extends StatefulWidget {
  const _PipelineHarness({
    required this.session,
    required this.dictation,
    required this.store,
    required this.vaultPath,
    super.key,
  });

  final OnboardingSession session;
  final DictationEngine dictation;
  final _SqliteInt8ChunkStore store;
  final String vaultPath;

  @override
  State<_PipelineHarness> createState() => _PipelineHarnessState();
}

class _PipelineHarnessState extends State<_PipelineHarness> {
  final _draft = TextEditingController();
  final _query = TextEditingController();
  late final RagSearchService _search = RagSearchService(
    embedder: _embed,
    store: widget.store,
  );
  late final MarkdownExportService _markdown = MarkdownExportService(
    pickDirectory: () async => widget.vaultPath,
    vault: MemoryMarkdownVaultStore(),
  );

  _PipelinePhase phase = _PipelinePhase.onboarding;
  JournalEntry? voiceEntry;
  RagSearchAnswer? answer;

  static const _ambient = AmbientContext(
    locality: 'London',
    weatherLabel: '18°C',
    stepCount: 4200,
  );

  void _showHome(OnboardingBaseline _) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => phase = _PipelinePhase.home);
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      _PipelinePhase.onboarding => ConversationalOnboardingScreen(
        session: widget.session,
        onFinished: _showHome,
      ),
      _PipelinePhase.home || _PipelinePhase.saved => _home(),
      _PipelinePhase.chat ||
          _PipelinePhase.searched ||
          _PipelinePhase.synced => _chat(),
    };
  }

  Widget _home() {
    return Scaffold(
      body: ListView(
        children: [
          const Text('Home'),
          TextField(controller: _draft),
          DictationMicBar(
            controller: _draft,
            engine: widget.dictation,
            haptic: () {},
          ),
          const AmbientContextPills(ambient: _ambient),
          TextButton(
            key: const Key('pipeline_save'),
            onPressed: _saveVoiceEntry,
            child: const Text('Save'),
          ),
          if (voiceEntry != null)
            TextButton(
              key: const Key('pipeline_open_chat'),
              onPressed: () => setState(() => phase = _PipelinePhase.chat),
              child: const Text('Chat with Your Past'),
            ),
        ],
      ),
    );
  }

  Widget _chat() {
    return Scaffold(
      body: ListView(
        children: [
          const Text('Chat with Your Past', key: Key('chat_with_your_past')),
          TextField(key: const Key('chat_query'), controller: _query),
          TextButton(
            key: const Key('chat_submit'),
            onPressed: _ask,
            child: const Text('Ask'),
          ),
          if (answer != null && answer!.citations.isNotEmpty)
            Text(answer!.citations.first.excerpt),
          TextButton(
            key: const Key('obsidian_sync'),
            onPressed: _syncVault,
            child: const Text('Sync to Obsidian'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveVoiceEntry() async {
    final transcript = _draft.text.trim();
    if (transcript.isEmpty) return;
    // The voice pipeline still writes entries through the flat factory.
    // ignore: deprecated_member_use_from_same_package
    final entry = JournalEntry(
      id: 'voice-entry',
      createdAt: DateTime.utc(2026, 9, 22, 12),
      transcript: transcript,
      durationSeconds: 12,
      reflection: Reflection(
        mood: 'calm',
        emotionalIntensity: 1,
        recurringThemes: const ['calm evening'],
        exactLanguagePattern: transcript,
        concreteObservation: transcript,
        repeatedSignal: transcript,
      ),
      display: const JournalDisplayMetadata(
        captureSource: 'dictation',
        ambientContext: _ambient,
      ),
    );
    final embedding = await _embed(transcript);
    await widget.store.upsert(
      TranscriptChunk(
        entryId: entry.id,
        chunkIndex: 0,
        text: transcript,
        startSeconds: 0,
        embedding: embedding,
      ),
    );
    await widget.store.upsert(
      TranscriptChunk(
        entryId: 'other-moment',
        chunkIndex: 0,
        text: 'A different afternoon with no overlap.',
        startSeconds: 0,
        embedding: await _embed('lunch near the station'),
      ),
    );
    setState(() {
      voiceEntry = entry;
      phase = _PipelinePhase.saved;
    });
  }

  Future<void> _ask() async {
    final result = await _search.search(_query.text);
    setState(() {
      answer = result;
      phase = _PipelinePhase.searched;
    });
  }

  Future<void> _syncVault() async {
    final entry = voiceEntry;
    if (entry == null) return;
    await _markdown.chooseVault();
    await _markdown.sync([entry]);
    setState(() => phase = _PipelinePhase.synced);
  }
}

Future<List<double>> _embed(String text) async {
  final lower = text.toLowerCase();
  final aboutFeeling =
      lower.contains('felt calm and hopeful') ||
      lower.contains('how did i feel');
  final values = Float32List(benchmarkEmbeddingDimensions);
  fillBenchmarkVector(values, aboutFeeling ? 42 : 7);
  if (lower.contains('how did i feel')) {
    values[0] += 0.02;
    var sumSquares = 0.0;
    for (final value in values) {
      sumSquares += value * value;
    }
    final inverse = 1 / math.sqrt(sumSquares);
    for (var i = 0; i < values.length; i++) {
      values[i] = values[i] * inverse;
    }
  }
  return values;
}

class _SqliteInt8ChunkStore implements TranscriptChunkStore {
  _SqliteInt8ChunkStore(this._database);

  final Database _database;
  final List<TranscriptChunk> _rows = [];

  @override
  Future<List<String>?> nearestKeys(
    List<double> query, {
    int limit = 5,
  }) async => null;

  @override
  Future<void> upsert(TranscriptChunk chunk) async {
    _rows
      ..removeWhere(
        (row) =>
            row.entryId == chunk.entryId && row.chunkIndex == chunk.chunkIndex,
      )
      ..add(chunk);
    final quantized = quantizeSymmetric(Float32List.fromList(chunk.embedding));
    final blob = Uint8List(quantized.codes.length);
    blob.buffer.asInt8List().setRange(0, quantized.codes.length, quantized.codes);
    await _database.rawInsert(
      '''
      INSERT OR REPLACE INTO pipeline_entries (id, transcript, embedding, alpha)
      VALUES (?, ?, ?, ?)
      ''',
      [chunk.entryId, chunk.text, blob, quantized.alpha],
    );
  }

  @override
  Future<List<TranscriptChunk>> all() async => List.unmodifiable(_rows);

  @override
  Future<List<VecMatch>?> nearestMatches(
    List<double> query, {
    int limit = 5,
  }) async {
    final queryVector = Float32List.fromList(query);
    final scored = <VecMatch>[];
    for (final row in await _database.rawQuery(
      'SELECT id, embedding, alpha FROM pipeline_entries',
    )) {
      final embedding = Int8Embedding(
        codes: _int8FromBlob(row['embedding']),
        alpha: (row['alpha']! as num).toDouble(),
      );
      scored.add(
        VecMatch(
          key: '${row['id']}#0',
          cosine: asymmetricCosine(queryVector, embedding),
        ),
      );
    }
    scored.sort((a, b) => b.cosine.compareTo(a.cosine));
    if (scored.length > limit) {
      return scored.sublist(0, limit);
    }
    return scored;
  }
}

class _SpeechSource {
  final _controller = StreamController<String>();

  Stream<String> get stream => _controller.stream;

  void add(String text) => _controller.add(text);

  void close() {
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
  }
}

class _ScriptedDictation implements DictationEngine {
  _ScriptedDictation(this.transcript);

  final String transcript;
  final _partials = StreamController<String>.broadcast();
  final _levels = StreamController<double>.broadcast();

  @override
  Stream<String> get partials => _partials.stream;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<void> start() async {
    _levels.add(0.4);
    _partials.add(transcript);
  }

  @override
  Future<void> stop() async {}

  void close() {
    unawaited(_partials.close());
    unawaited(_levels.close());
  }
}

String Function() _ids() {
  var count = 0;
  return () {
    count += 1;
    return 'onboarding-$count';
  };
}

Int8List _int8FromBlob(Object? value) {
  final bytes = value is Uint8List
      ? value
      : Uint8List.fromList((value! as List).cast<int>());
  final codes = Int8List(bytes.length);
  codes.buffer.asUint8List().setRange(0, bytes.length, bytes);
  return codes;
}
