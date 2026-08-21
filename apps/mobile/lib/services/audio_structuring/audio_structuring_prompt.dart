import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// ChatML prompts for turning raw STT transcripts into structured journal entries.
abstract final class AudioStructuringPrompt {
  AudioStructuringPrompt._();

  static const taskMarker = 'structure_journal_entry';

  static const _systemPrompt = '''
You are a private, on-device journal editor. Your job is to transform a raw, rambling voice transcript into a clear, coherent journal entry.

Rules:
- Preserve the speaker's meaning, facts, names, and emotional tone.
- Remove filler words, false starts, repetitions, and transcription noise.
- Write in first person unless the transcript clearly uses another voice.
- Organize into short paragraphs that read naturally.
- Do not invent events, people, or feelings that are not supported by the transcript.
- Do not mention that you edited or summarized the text.
- Output only the finished journal entry — no title, labels, markdown, or commentary.
''';

  static String buildChatMlPrompt(String rawTranscript) {
    final normalized = rawTranscript.replaceAll(RegExp(r'\s+'), ' ').trim();
    return ChatMLFormat().formatMessages([
      {'role': 'system', 'content': _systemPrompt},
      {
        'role': 'user',
        'content': '''
Task: $taskMarker

Raw voice transcript:
"""
$normalized
"""

Write the cleaned, structured journal entry now.
''',
      },
    ]);
  }
}
