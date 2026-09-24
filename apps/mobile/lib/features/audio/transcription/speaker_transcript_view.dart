import 'package:archiveme_mobile/features/audio/transcription/speaker_transcript.dart';
import 'package:flutter/material.dart';

/// Chat bubbles for a meeting transcript, one group per speaker.
class SpeakerTranscriptView extends StatelessWidget {
  const SpeakerTranscriptView({required this.transcript, super.key});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    final diarized = DiarizedTranscript.parseLabeled(transcript);
    if (diarized == null) return const SizedBox.shrink();
    return Column(
      key: const Key('speaker_transcript_bubbles'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final turn in diarized.turns) ...[
          const SizedBox(height: 8),
          Align(
            alignment: turn.speakerLabel == 'Speaker A'
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: turn.speakerLabel == 'Speaker A'
                    ? const Color(0xFFF3E8FF)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    turn.speakerLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(turn.text),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
