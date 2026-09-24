import 'dart:async';

import 'package:archiveme_mobile/features/search/vector_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One turn in the local search conversation.
class ChatSearchMessage {
  const ChatSearchMessage({
    required this.role,
    required this.text,
    this.citations = const [],
  });

  final ChatSearchRole role;
  final String text;
  final List<SemanticSearchHit> citations;

  ChatSearchMessage copyWith({
    String? text,
    List<SemanticSearchHit>? citations,
  }) {
    return ChatSearchMessage(
      role: role,
      text: text ?? this.text,
      citations: citations ?? this.citations,
    );
  }
}

enum ChatSearchRole { person, archive }

/// Conversational search over local sqlite-vec matches.
///
/// A query runs only when the person submits it. Typing does not embed,
/// search, or comment on the draft.
class ChatSearchScreen extends ConsumerStatefulWidget {
  const ChatSearchScreen({super.key, this.onOpenCitation});

  final ValueChanged<String>? onOpenCitation;

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  final _controller = TextEditingController();
  final _messages = <ChatSearchMessage>[];
  var _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search your archive')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('chat_search_transcript'),
              padding: const EdgeInsets.all(16),
              children: [
                for (var index = 0; index < _messages.length; index++)
                  _MessageBubble(
                    message: _messages[index],
                    onOpenCitation: _openCitation,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat_search_field'),
                    controller: _controller,
                    enabled: !_busy,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Ask about something you saved',
                    ),
                    onSubmitted: _busy
                        ? null
                        : (value) => unawaited(_submit(value)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('chat_search_send'),
                  onPressed: _busy
                      ? null
                      : () => unawaited(_submit(_controller.text)),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(String raw) async {
    final query = raw.trim();
    if (query.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _messages
        ..add(ChatSearchMessage(role: ChatSearchRole.person, text: query))
        ..add(
          const ChatSearchMessage(role: ChatSearchRole.archive, text: ''),
        );
      _controller.clear();
    });
    final answerIndex = _messages.length - 1;
    final service = ref.read(semanticSearchServiceProvider);
    final result = await service.ask(query);
    await for (final partial in streamConversationalReply(result.reply)) {
      if (!mounted) return;
      setState(() {
        _messages[answerIndex] = _messages[answerIndex].copyWith(text: partial);
      });
    }
    if (!mounted) return;
    setState(() {
      _messages[answerIndex] = _messages[answerIndex].copyWith(
        text: result.reply,
        citations: result.citations,
      );
      _busy = false;
    });
  }

  void _openCitation(String entryId) {
    final handler = widget.onOpenCitation;
    if (handler != null) {
      handler(entryId);
      return;
    }
    if (GoRouter.maybeOf(context) != null) {
      unawaited(context.push('/entry/$entryId'));
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onOpenCitation,
  });

  final ChatSearchMessage message;
  final ValueChanged<String> onOpenCitation;

  @override
  Widget build(BuildContext context) {
    final fromArchive = message.role == ChatSearchRole.archive;
    final seen = <String>{};
    final citations = [
      for (final hit in message.citations)
        if (seen.add(hit.entryId)) hit,
    ];
    return Align(
      alignment: fromArchive ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text),
                if (citations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hit in citations)
                        ActionChip(
                          key: Key('citation_chip_${hit.entryId}'),
                          label: Text(_chipLabel(hit.text)),
                          onPressed: () => onOpenCitation(hit.entryId),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _chipLabel(String text) {
    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= 42) return trimmed;
    return '${trimmed.substring(0, 39)}...';
  }
}
