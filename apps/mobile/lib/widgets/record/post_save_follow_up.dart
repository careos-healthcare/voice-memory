import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/capture/services/follow_up_service.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/live_draft_transcript.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// One question after a save. Stops after three turns.
///
/// Each answer is stored as its own journal entry linked to the moment
/// that was just saved. Hidden while [V1CapabilityRegistry.postSaveFollowUp]
/// is off.
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
  StreamSubscription<String>? _partials;
  FollowUpReflection? _followUp;
  var _listening = false;

  @override
  void initState() {
    super.initState();
    if (AppFlags.postSaveFollowUp) {
      unawaited(_loadFollowUp());
    }
  }

  @override
  void dispose() {
    if (_listening) {
      unawaited(LiveDraftTranscript.stop());
      unawaited(_partials?.cancel());
    }
    _answer.dispose();
    super.dispose();
  }

  Future<void> _loadFollowUp() async {
    final followUp = await FollowUpService().forEntry(widget.entry);
    if (!mounted || followUp == null) return;
    setState(() => _followUp = followUp);
  }

  /// First sentence of the saved moment, or the whole moment when it is short.
  static String sentenceFrom(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) return '';
    final end = RegExp('[.!?]', unicode: true).firstMatch(text);
    if (end != null) return text.substring(0, end.end).trim();
    if (text.length <= 160) return text;
    final cut = text.lastIndexOf(' ', 160);
    if (cut > 40) return text.substring(0, cut);
    return text;
  }

  String get _question {
    final cited = _followUp;
    if (_turns.isEmpty && cited != null) return cited.question;
    final quote = sentenceFrom(widget.entry.transcript);
    if (quote.isEmpty) {
      return switch (_turns.length) {
        0 => 'How does this sit with you today?',
        1 => 'What would you want to remember about this moment?',
        _ => 'Is there one detail you want to keep?',
      };
    }
    return switch (_turns.length) {
      0 => 'You mentioned $quote How does that sit with you today?',
      1 => 'You said $quote What would you want to remember about that?',
      _ => 'You wrote $quote Is there one detail you want to keep?',
    };
  }

  Future<void> _submit() async {
    final text = _answer.text.trim();
    if (text.isEmpty || _turns.length >= PostSaveFollowUp.maxTurns) return;
    setState(() {
      _turns.add(text);
      _answer.clear();
    });
    await _saveAnswer(text);
  }

  Future<void> _saveAnswer(String text) async {
    if (!AppServices.isInitialized) return;
    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();
    final note = JournalEntry(
      id: id,
      createdAt: now,
      transcript: text,
      durationSeconds: 0,
      reflection: const Reflection(
        mood: '',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      captureSource: 'post_save_follow_up',
      parentHookId: widget.entry.id,
    );
    await AppServices.instance.journalStore.save(note, captureKind: 'typed');
  }

  Future<void> _toggleMic() async {
    if (!LiveDraftTranscript.supportsOnDeviceStreaming) return;
    if (_listening) {
      await _partials?.cancel();
      _partials = null;
      await LiveDraftTranscript.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    _partials = LiveDraftTranscript.partials().listen((text) {
      if (!mounted || text.trim().isEmpty) return;
      _answer.text = text;
      _answer.selection = TextSelection.collapsed(offset: _answer.text.length);
    });
    await LiveDraftTranscript.start();
  }

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.postSaveFollowUp) {
      return const SizedBox.shrink();
    }
    final done = _turns.length >= PostSaveFollowUp.maxTurns;
    final theme = Theme.of(context);
    final cited = _followUp;
    return Column(
      key: const Key('post_save_follow_up'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cited != null && _turns.isEmpty)
          FollowUpCitationBlock(
            followUp: cited,
            currentEntryId: widget.entry.id,
          )
        else
          Text(
            _question,
            key: const Key('post_save_follow_up_question'),
            style: theme.textTheme.bodyLarge,
          ),
        if (!done) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('post_save_follow_up_answer'),
            controller: _answer,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'A short answer',
              suffixIcon: IconButton(
                key: const Key('post_save_follow_up_mic'),
                tooltip: _listening ? 'Stop' : 'Speak your answer',
                onPressed: _toggleMic,
                icon: Icon(_listening ? Icons.mic : Icons.mic_none_rounded),
              ),
            ),
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

/// Quotes from the past entry and today's entry, then the question they explain.
class FollowUpCitationBlock extends StatelessWidget {
  const FollowUpCitationBlock({
    required this.followUp,
    required this.currentEntryId,
    super.key,
  });

  final FollowUpReflection followUp;
  final String currentEntryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          followUp.citation,
          key: const Key('post_save_follow_up_citation'),
          style: theme.textTheme.bodyMedium,
        ),
        ViewEvidenceInlineLink(
          entryIds: [followUp.pastEntryId, currentEntryId],
          surface: 'post_save_follow_up',
          claimContext: followUp.citation,
        ),
        Text(
          followUp.question,
          key: const Key('post_save_follow_up_question'),
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
