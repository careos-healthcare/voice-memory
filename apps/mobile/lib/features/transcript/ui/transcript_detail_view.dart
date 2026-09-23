import 'package:archiveme_mobile/features/ai_coaching/ask_the_coach_panel.dart';
import 'package:archiveme_mobile/features/ai_coaching/ask_the_coach_service.dart';
import 'package:archiveme_mobile/features/transcript/ui/transcript_markup.dart';
import 'package:flutter/material.dart';

/// Raw transcript with phrase tags, shareable clips, and an optional local
/// coach chat.
class TranscriptDetailView extends StatefulWidget {
  const TranscriptDetailView({
    required this.entryId,
    required this.transcript,
    super.key,
    this.coach,
    this.showRawTranscript = true,
    this.bodyKey = const Key('entry_detail_recorded_body'),
  });

  final String entryId;
  final String transcript;
  final AskTheCoachService? coach;
  final bool showRawTranscript;
  final Key bodyKey;

  @override
  State<TranscriptDetailView> createState() => _TranscriptDetailViewState();
}

class _TranscriptDetailViewState extends State<TranscriptDetailView> {
  TextSelection? _selection;
  final _tag = TextEditingController();
  final _phrase = TextEditingController();
  late final TranscriptMarkup _markup = TranscriptMarkup(widget.entryId);

  @override
  void dispose() {
    _tag.dispose();
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transcript = widget.transcript.trim();
    if (transcript.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showRawTranscript)
          SelectableText(
            transcript,
            key: widget.bodyKey,
            style: const TextStyle(height: 1.45),
            onSelectionChanged: (selection, _) {
              setState(() => _selection = selection);
            },
          ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('transcript_phrase_input'),
          controller: _phrase,
          decoration: const InputDecoration(hintText: 'Highlight a phrase'),
        ),
        TextField(
          key: const Key('transcript_tag_input'),
          controller: _tag,
          decoration: const InputDecoration(hintText: 'Tag'),
        ),
        TextButton(
          key: const Key('transcript_save_clip'),
          onPressed: _saveClip,
          child: const Text('Save clip'),
        ),
        for (final clip in _markup.clips)
          Text(clip.shareText, key: Key('transcript_clip_${clip.start}')),
        if (widget.coach != null) ...[
          const SizedBox(height: 16),
          AskTheCoachPanel(service: widget.coach!),
        ],
      ],
    );
  }

  void _saveClip() {
    final transcript = widget.transcript;
    final selection = _selection;
    var start = 0;
    var end = 0;
    if (selection != null && selection.isValid && !selection.isCollapsed) {
      start = selection.start;
      end = selection.end;
    } else {
      final phrase = _phrase.text.trim();
      final index = phrase.isEmpty ? -1 : transcript.indexOf(phrase);
      if (index < 0) return;
      start = index;
      end = index + phrase.length;
    }
    final clip = _markup.saveClip(
      transcript: transcript,
      start: start,
      end: end,
      tags: _tag.text.split(','),
    );
    if (clip == null || !mounted) return;
    setState(() {
      _tag.clear();
      _phrase.clear();
    });
  }
}
