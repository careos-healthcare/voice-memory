import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// One cited question after a save. Stops after three turns.
class PostSaveFollowUp extends StatefulWidget {
  const PostSaveFollowUp({required this.entry, super.key});

  final JournalEntry entry;

  static const maxTurns = 3;

  @override
  State<PostSaveFollowUp> createState() => _PostSaveFollowUpState();
}

class _PostSaveFollowUpState extends State<PostSaveFollowUp> {
  final _answer = TextEditingController();
  final _turns = <String>[];

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  String get _cited {
    final text = _turns.isEmpty
        ? widget.entry.transcript.trim()
        : _turns.last;
    if (text.length <= 48) return text.isEmpty ? 'that' : text;
    return '${text.substring(0, 48)}…';
  }

  String get _question {
    if (_turns.isEmpty) {
      return 'You mentioned $_cited. How does that sit with you today?';
    }
    if (_turns.length == 1) {
      return 'You said $_cited. What would you want to remember about that?';
    }
    return 'You wrote $_cited. Is there one detail you want to keep?';
  }

  void _submit() {
    final text = _answer.text.trim();
    if (text.isEmpty || _turns.length >= PostSaveFollowUp.maxTurns) return;
    setState(() {
      _turns.add(text);
      _answer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _turns.length >= PostSaveFollowUp.maxTurns;
    final theme = Theme.of(context);
    return Column(
      key: const Key('post_save_follow_up'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_question, style: theme.textTheme.bodyLarge),
        ViewEvidenceInlineLink(
          entryIds: [widget.entry.id],
          surface: 'post_save_follow_up',
          claimContext: _question,
        ),
        if (!done) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('post_save_follow_up_answer'),
            controller: _answer,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(hintText: 'A short answer'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('post_save_follow_up_send'),
              onPressed: _submit,
              child: const Text('Answer'),
            ),
          ),
        ] else
          Text(
            'That’s enough for this moment.',
            key: const Key('post_save_follow_up_done'),
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}
