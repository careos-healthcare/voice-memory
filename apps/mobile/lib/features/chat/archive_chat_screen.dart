import 'dart:async';

import 'package:archiveme_mobile/features/audio/local_speech_synthesizer.dart';
import 'package:archiveme_mobile/features/chat/archive_chat_service.dart';
import 'package:archiveme_mobile/features/chat/chat_notifier.dart';
import 'package:archiveme_mobile/features/metadata/entry_metadata_views.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starter prompts shown above the composer.
const archiveChatSuggestions = <String>[
  'What made me happy last month?',
  'Summarize my progress on career goals',
  'When was the last time I saw Ada?',
];

/// Which assistant bubble is currently read aloud.
class ReadAloudSelection extends Notifier<String?> {
  @override
  String? build() => null;

  set selected(String? messageId) => state = messageId;
}

final readAloudSelectionProvider =
    NotifierProvider<ReadAloudSelection, String?>(
      ReadAloudSelection.new,
    );

/// Conversational archive chat with streaming replies and source chips.
class ArchiveChatScreen extends ConsumerStatefulWidget {
  const ArchiveChatScreen({super.key});

  @override
  ConsumerState<ArchiveChatScreen> createState() => _ArchiveChatScreenState();
}

class _ArchiveChatScreenState extends ConsumerState<ArchiveChatScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(chatNotifierProvider.notifier).load());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatNotifierProvider);
    ref.listen(chatNotifierProvider, (previous, next) {
      final selected = ref.read(readAloudSelectionProvider);
      if (selected == null) return;
      ChatMessage? message;
      for (final candidate in next.messages) {
        if (candidate.id == selected) message = candidate;
      }
      if (message == null) return;
      String? priorBody;
      for (final candidate in previous?.messages ?? const <ChatMessage>[]) {
        if (candidate.id == selected) priorBody = candidate.body;
      }
      if (priorBody != null && message.body.length > priorBody.length) {
        unawaited(
          ref
              .read(localSpeechSynthesizerProvider.notifier)
              .pushToken(message.body.substring(priorBody.length)),
        );
      }
      if ((previous?.streaming ?? false) && !next.streaming) {
        unawaited(
          ref.read(localSpeechSynthesizerProvider.notifier).finishUtterance(),
        );
      }
    });
    _keepLatestVisible();
    return Scaffold(
      key: const Key('archive_chat_screen'),
      appBar: AppBar(title: const Text('Archive chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(AppTokens.spacing3),
              itemCount: chat.messages.length,
              itemBuilder: (context, index) {
                return _ChatBubble(message: chat.messages[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spacing3,
              0,
              AppTokens.spacing3,
              AppTokens.spacing2,
            ),
            child: Wrap(
              spacing: AppTokens.spacing2,
              runSpacing: AppTokens.spacing2,
              children: [
                for (final suggestion in archiveChatSuggestions)
                  ActionChip(
                    key: Key('chat_suggestion_${_suggestionKey(suggestion)}'),
                    label: Text(suggestion),
                    onPressed: chat.streaming
                        ? null
                        : () => unawaited(_send(suggestion)),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spacing3,
                0,
                AppTokens.spacing3,
                AppTokens.spacing3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chat_input'),
                      controller: _input,
                      enabled: !chat.streaming,
                      decoration: const InputDecoration(
                        hintText: 'Ask about a moment',
                      ),
                      onSubmitted: chat.streaming
                          ? null
                          : (value) => unawaited(_send(value)),
                    ),
                  ),
                  if (chat.streaming)
                    IconButton(
                      key: const Key('chat_cancel'),
                      onPressed: () {
                        ref.read(chatNotifierProvider.notifier).cancel();
                      },
                      icon: const Icon(Icons.stop),
                      tooltip: 'Stop',
                    )
                  else
                    IconButton(
                      key: const Key('chat_send'),
                      onPressed: () => unawaited(_send(_input.text)),
                      icon: const Icon(Icons.send),
                      tooltip: 'Send',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _input.clear();
    await ref.read(chatNotifierProvider.notifier).send(trimmed);
  }

  void _keepLatestVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.maxScrollExtent <= position.pixels) return;
      _scroll.jumpTo(position.maxScrollExtent);
    });
  }
}

class _ChatBubble extends ConsumerWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == ChatMessageRole.user;
    final readingAloud = ref.watch(readAloudSelectionProvider) == message.id;
    final width = MediaQuery.sizeOf(context).width * 0.82;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spacing3),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isUser ? AppTokens.primary600 : AppTokens.neutral200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.spacing3),
                  child: isUser
                      ? Text(
                          message.body,
                          key: Key('chat_message_${message.id}'),
                          style: const TextStyle(color: Colors.white),
                        )
                      : ChatMarkdownBody(
                          key: Key('chat_message_${message.id}'),
                          text: message.body,
                          style: const TextStyle(color: Colors.black),
                        ),
                ),
              ),
            ),
          ),
          if (!isUser && message.body.trim().isNotEmpty)
            TextButton(
              key: Key('chat_read_aloud_${message.id}'),
              onPressed: () {
                final selection = ref.read(readAloudSelectionProvider.notifier);
                final synthesizer = ref.read(
                  localSpeechSynthesizerProvider.notifier,
                );
                if (readingAloud) {
                  synthesizer.interrupt();
                  selection.selected = null;
                  return;
                }
                selection.selected = message.id;
                unawaited(synthesizer.speakText(message.body));
              },
              child: const Text('Read aloud'),
            ),
          if (!isUser && message.sources.isNotEmpty) ...[
            const SizedBox(height: AppTokens.spacing2),
            Text(
              'Source Moments',
              key: Key('chat_sources_${message.id}'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: AppTokens.spacing2),
            Wrap(
              spacing: AppTokens.spacing2,
              runSpacing: AppTokens.spacing2,
              children: [
                for (final source in message.sources)
                  ActionChip(
                    key: Key('chat_source_${source.entryId}'),
                    label: Text(source.preview),
                    onPressed: () {
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => _MomentPage(moment: source),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MomentPage extends StatelessWidget {
  const _MomentPage({required this.moment});

  final ChatContextMoment moment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moment')),
      body: Padding(
        padding: const EdgeInsets.all(AppTokens.spacing3),
        child: EntryDetailView(
          transcript: moment.transcript,
          metadata: moment.metadata,
        ),
      ),
    );
  }
}

/// Renders `**bold**` spans inside a chat bubble.
class ChatMarkdownBody extends StatelessWidget {
  const ChatMarkdownBody({required this.text, super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(TextSpan(children: chatMarkdownSpans(text, base)));
  }
}

/// Splits [text] into plain and bold spans.
List<InlineSpan> chatMarkdownSpans(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  var start = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > start) {
      spans.add(
        TextSpan(text: text.substring(start, match.start), style: base),
      );
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: base.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    start = match.end;
  }
  if (start < text.length || spans.isEmpty) {
    spans.add(TextSpan(text: text.substring(start), style: base));
  }
  return spans;
}

String _suggestionKey(String suggestion) {
  if (suggestion.startsWith('What made me happy')) return 'happy';
  if (suggestion.startsWith('Summarize')) return 'career';
  return 'ada';
}
