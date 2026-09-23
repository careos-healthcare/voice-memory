import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/llm/llm_router.dart';
import 'package:archiveme_mobile/features/chat/archive_chat_screen.dart';
import 'package:archiveme_mobile/features/chat/archive_chat_service.dart';
import 'package:archiveme_mobile/features/chat/chat_notifier.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_024_chat_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('relative time labels stay short', () {
    final now = DateTime.utc(2026, 9, 23, 12);
    expect(relativeChatTime(now, now), 'Today');
    expect(
      relativeChatTime(now.subtract(const Duration(days: 1)), now),
      'Yesterday',
    );
    expect(
      relativeChatTime(now.subtract(const Duration(days: 3)), now),
      '3 days ago',
    );
    expect(
      relativeChatTime(now.subtract(const Duration(days: 40)), now),
      '1 month ago',
    );
  });

  test('markdown keeps bold words', () {
    final spans = chatMarkdownSpans(
      'You saw **Ada**.',
      const TextStyle(),
    );
    expect(spans, hasLength(3));
    expect((spans[1] as TextSpan).text, 'Ada');
    expect((spans[1] as TextSpan).style?.fontWeight, FontWeight.w700);
  });

  test('cloud key routes the chat reply', () async {
    final router = LlmRouter(
      settings: CloudByokSettings(
        enabled: true,
        provider: CloudByokProvider.custom,
        apiKey: 'test-key',
        endpoint: Uri.parse('https://example.test/chat'),
      ),
      cloud: (settings, prompt) async => 'From your moments.',
      local: (prompt) async => 'local',
    );
    final service = ArchiveChatService(router: router);
    final retrieval = await service.retrieve('When was the last time I saw Ada?');
    expect(retrieval.target, LlmExecutionTarget.cloudByok);
    final parts = await service
        .streamReply(
          synthesized: retrieval.synthesized,
          cancel: ExecutionCancelToken(),
        )
        .toList();
    expect(parts.last, 'From your moments.');
  });

  test('retrieval cites the linked moment and stores the turn', () async {
    final directory = await Directory.systemTemp.createTemp('archive-chat');
    final app = await openTestAppSqliteDatabase(
      filePath: '${directory.path}/archive.db',
    );
    addTearDown(() async {
      await app.close();
      AppSqliteDatabase.resetForTest();
    });
    final now = DateTime.utc(2026, 9, 23, 12);
    var ticks = 0;
    DateTime clock() {
      ticks += 1;
      return now.add(Duration(milliseconds: ticks));
    }

    final db = app.database;
    final seenAt = now.subtract(const Duration(days: 3)).millisecondsSinceEpoch;
    await db.insert('journal_entries', {
      'id': 'moment-ada',
      'created_at': seenAt,
      'updated_at': seenAt,
      'is_archived': 0,
      'transcript': 'Met Ada at Banstead.',
      'has_verified_proof': 0,
      'payload_json': '{}',
      'ambient_metadata': jsonEncode(
        const AmbientMetadata(city: 'Banstead').toJson(),
      ),
    });
    await db.insert('journal_entries', {
      'id': 'moment-milk',
      'created_at': seenAt,
      'updated_at': seenAt,
      'is_archived': 0,
      'transcript': 'Bought milk.',
      'has_verified_proof': 0,
      'payload_json': '{}',
    });
    await db.insert('entities', {
      'id': 'people:ada',
      'name': 'Ada',
      'category': 'people',
      'description': '',
      'created_at': seenAt,
    });
    await db.insert('entry_entities', {
      'entry_id': 'moment-ada',
      'entity_id': 'people:ada',
    });

    String? seenPrompt;
    final service = ArchiveChatService(
      database: db,
      clock: clock,
      topK: 1,
      router: LlmRouter(
        local: (prompt) async {
          seenPrompt = prompt;
          return 'You saw Ada.';
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [
        chatNotifierProvider.overrideWith(
          () => ChatNotifier(service: service, database: db, clock: clock),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(chatNotifierProvider.notifier)
        .send('When was the last time I saw Ada?');

    final state = container.read(chatNotifierProvider);
    expect(state.streaming, isFalse);
    expect(state.messages, hasLength(2));
    expect(state.messages.last.body, 'You saw Ada.');
    expect(state.messages.last.sources.single.entryId, 'moment-ada');
    expect(seenPrompt, contains('Met Ada at Banstead.'));
    expect(seenPrompt, contains('3 days ago'));
    expect(seenPrompt, contains('Place: Banstead.'));
    expect(seenPrompt, contains('Entities: Ada.'));

    final stored = await db.query(Migration024ChatMessages.table);
    expect(stored, hasLength(2));
    expect(stored.last['source_entry_ids'], 'moment-ada');
  });

  test('cancel keeps the partial reply', () async {
    final service = _PausingChat();
    final container = ProviderContainer(
      overrides: [
        chatNotifierProvider.overrideWith(() => ChatNotifier(service: service)),
      ],
    );
    addTearDown(container.dispose);
    final pending = container.read(chatNotifierProvider.notifier).send('Ada');
    await pumpEventQueue();
    expect(container.read(chatNotifierProvider).messages.last.body, 'Saw ');
    container.read(chatNotifierProvider.notifier).cancel();
    service.release();
    await pending;
    final last = container.read(chatNotifierProvider).messages.last;
    expect(last.body, 'Saw ');
    expect(last.cancelled, isTrue);
    expect(container.read(chatNotifierProvider).streaming, isFalse);
  });

  testWidgets('suggestion opens a cited moment', (tester) async {
    final moment = ChatContextMoment(
      entryId: 'moment-ada',
      createdAt: DateTime.utc(2026, 9, 20),
      relativeTime: '3 days ago',
      location: 'Banstead',
      entities: const ['Ada'],
      transcript: 'Met Ada at Banstead.',
      metadata: const AmbientMetadata(city: 'Banstead'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatNotifierProvider.overrideWith(
            () => ChatNotifier(
              service: _ScriptedChat(
                moments: [moment],
                chunks: const ['You saw **Ada**.'],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ArchiveChatScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('What made me happy last month?'), findsOneWidget);
    expect(find.text('Summarize my progress on career goals'), findsOneWidget);
    expect(find.text('When was the last time I saw Ada?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat_suggestion_ada')));
    await tester.pumpAndSettle();

    expect(find.text('You saw Ada.'), findsOneWidget);
    expect(find.text('Source Moments'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat_source_moment-ada')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entry_detail_recorded_body')), findsOneWidget);
    expect(find.text('Met Ada at Banstead.'), findsWidgets);
  });
}

class _ScriptedChat extends ArchiveChatService {
  _ScriptedChat({required this.moments, required this.chunks});

  final List<ChatContextMoment> moments;
  final List<String> chunks;

  @override
  Future<ArchiveChatRetrieval> retrieve(
    String prompt, {
    List<ChatTurn> history = const [],
  }) async {
    return ArchiveChatRetrieval(
      moments: moments,
      synthesized: prompt,
      target: LlmExecutionTarget.localOffline,
    );
  }

  @override
  Stream<String> streamReply({
    required String synthesized,
    required ExecutionCancelToken cancel,
  }) async* {
    for (final chunk in chunks) {
      cancel.throwIfCancelled();
      yield chunk;
    }
  }
}

class _PausingChat extends ArchiveChatService {
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<ArchiveChatRetrieval> retrieve(
    String prompt, {
    List<ChatTurn> history = const [],
  }) async {
    return ArchiveChatRetrieval(
      moments: const [],
      synthesized: prompt,
      target: LlmExecutionTarget.localOffline,
    );
  }

  @override
  Stream<String> streamReply({
    required String synthesized,
    required ExecutionCancelToken cancel,
  }) async* {
    yield 'Saw ';
    await _gate.future;
    cancel.throwIfCancelled();
    yield 'Saw Ada.';
  }
}
