import 'dart:convert';

import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/features/chat/archive_chat_service.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_024_chat_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Who wrote a stored chat turn.
abstract final class ChatMessageRole {
  static const user = 'user';
  static const assistant = 'assistant';
}

/// One persisted chat turn, including the moments a reply cites.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.body,
    required this.createdAt,
    this.sources = const [],
    this.cancelled = false,
  });

  factory ChatMessage.fromRow(Map<String, Object?> row) {
    final raw = '${row['sources_json'] ?? '[]'}';
    final sources = <ChatContextMoment>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            sources.add(
              ChatContextMoment.fromJson(Map<String, Object?>.from(item)),
            );
          }
        }
      }
    } on Object {
      sources.clear();
    }
    return ChatMessage(
      id: '${row['id']}',
      role: '${row['role']}',
      body: '${row['body'] ?? ''}',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num?)?.toInt() ?? 0,
      ),
      sources: sources,
      cancelled: (row['cancelled'] as num?)?.toInt() == 1,
    );
  }

  final String id;
  final String role;
  final String body;
  final DateTime createdAt;
  final List<ChatContextMoment> sources;
  final bool cancelled;

  ChatMessage copyWith({String? body, bool? cancelled}) {
    return ChatMessage(
      id: id,
      role: role,
      body: body ?? this.body,
      createdAt: createdAt,
      sources: sources,
      cancelled: cancelled ?? this.cancelled,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'role': role,
    'body': body,
    'created_at': createdAt.millisecondsSinceEpoch,
    'source_entry_ids': sources.map((source) => source.entryId).join(','),
    'sources_json': jsonEncode([
      for (final source in sources) source.toJson(),
    ]),
    'cancelled': cancelled ? 1 : 0,
  };
}

/// Visible chat transcript and whether a reply is still streaming.
class ChatState {
  const ChatState({this.messages = const [], this.streaming = false});

  final List<ChatMessage> messages;
  final bool streaming;

  ChatState copyWith({List<ChatMessage>? messages, bool? streaming}) {
    return ChatState(
      messages: messages ?? this.messages,
      streaming: streaming ?? this.streaming,
    );
  }
}

/// Reads and writes [Migration024ChatMessages.table].
class ChatMessageStore {
  const ChatMessageStore(this.database);

  final DatabaseExecutor database;

  Future<List<ChatMessage>> load() async {
    final rows = await database.query(
      Migration024ChatMessages.table,
      orderBy: 'created_at ASC',
    );
    return [for (final row in rows) ChatMessage.fromRow(row)];
  }

  Future<void> save(ChatMessage message) {
    return database.insert(
      Migration024ChatMessages.table,
      message.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// Multi-turn archive chat with streaming updates and cancellation.
class ChatNotifier extends Notifier<ChatState> {
  ChatNotifier({this.service, this.database, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ArchiveChatService? service;
  final DatabaseExecutor? database;
  final DateTime Function() _clock;

  ArchiveChatService? _service;
  ChatMessageStore? _store;
  ExecutionCancelToken? _cancel;
  var _sequence = 0;

  @override
  ChatState build() {
    final override = service;
    if (override != null) {
      _service = override;
      final db = database;
      _store = db == null ? null : ChatMessageStore(db);
    } else {
      final db = ref.watch(appSqliteDatabaseProvider).database;
      _service = ArchiveChatService(database: db);
      _store = ChatMessageStore(db);
    }
    ref.onDispose(cancel);
    return const ChatState();
  }

  Future<void> load() async {
    final store = _store;
    if (store == null || state.streaming || state.messages.isNotEmpty) return;
    final loaded = await store.load();
    if (!ref.mounted || state.messages.isNotEmpty) return;
    state = ChatState(messages: loaded);
  }

  void cancel() => _cancel?.cancel();

  Future<void> send(String text) async {
    final trimmed = text.trim();
    final engine = _service;
    if (trimmed.isEmpty || state.streaming || engine == null) return;
    final cancel = ExecutionCancelToken();
    _cancel = cancel;
    final user = ChatMessage(
      id: _nextId(ChatMessageRole.user),
      role: ChatMessageRole.user,
      body: trimmed,
      createdAt: _clock(),
    );
    final history = [
      for (final message in state.messages)
        if (message.body.trim().isNotEmpty)
          ChatTurn(role: message.role, body: message.body),
    ];
    state = ChatState(messages: [...state.messages, user], streaming: true);
    await _store?.save(user);
    try {
      final retrieval = await engine.retrieve(trimmed, history: history);
      if (!ref.mounted) return;
      if (cancel.isCancelled) {
        await _finish(cancelled: true);
        return;
      }
      final assistant = ChatMessage(
        id: _nextId(ChatMessageRole.assistant),
        role: ChatMessageRole.assistant,
        body: '',
        createdAt: _clock(),
        sources: retrieval.moments,
      );
      state = ChatState(
        messages: [...state.messages, assistant],
        streaming: true,
      );
      await for (final partial in engine.streamReply(
        synthesized: retrieval.synthesized,
        cancel: cancel,
      )) {
        if (!ref.mounted) return;
        _replaceLast(assistant.copyWith(body: partial));
      }
      await _finish(cancelled: cancel.isCancelled);
    } on ExecutionCancelledException {
      await _finish(cancelled: true);
    } finally {
      if (ref.mounted && state.streaming) {
        state = ChatState(messages: state.messages);
      }
    }
  }

  Future<void> _finish({required bool cancelled}) async {
    if (!ref.mounted) return;
    final messages = [...state.messages];
    if (messages.isNotEmpty &&
        messages.last.role == ChatMessageRole.assistant) {
      final last = messages.last.copyWith(cancelled: cancelled);
      messages[messages.length - 1] = last;
      await _store?.save(last);
    }
    if (!ref.mounted) return;
    state = ChatState(messages: messages);
  }

  void _replaceLast(ChatMessage message) {
    if (!ref.mounted || state.messages.isEmpty) return;
    final messages = [...state.messages];
    messages[messages.length - 1] = message;
    state = ChatState(messages: messages, streaming: true);
  }

  String _nextId(String role) {
    _sequence += 1;
    return '${_clock().microsecondsSinceEpoch}-$role-$_sequence';
  }
}

final chatNotifierProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
