/// Archive-aware conversation starters — no LLM, no coaching tone.

class ArchivePrompt {
  ArchivePrompt({
    required this.id,
    required this.type,
    required this.text,
    required this.priority,
  });

  final String id;
  final String type;
  final String text;
  final int priority;
}

class ArchivePromptSet {
  ArchivePromptSet({required this.mode, required this.prompts});

  final String mode;
  final List<ArchivePrompt> prompts;
}

const firstSessionPrompts = [
  'What happened today that stuck with you?',
  'What annoyed you today?',
  'Did anything surprise you today?',
  'What are you thinking about right now?',
  'Anything taking up mental space?',
];

const generalCapture = 'What is taking up mental space today?';

const openUncertain =
    'The archive is still uncertain here. What else should it know?';

ArchivePromptSet buildArchivePrompts({
  required bool hasBelief,
  required bool strengthening,
  required bool weakening,
  required bool hasRecentChange,
  required bool hasOpenQuestion,
  required String? missingAreaLabel,
  required String? beliefSnippet,
}) {
  if (!hasBelief) {
    return ArchivePromptSet(
      mode: 'first_session',
      prompts: [
        for (var i = 0; i < firstSessionPrompts.length; i++)
          ArchivePrompt(
            id: 'ap-$i',
            type: 'GENERAL_CAPTURE_PROMPT',
            text: firstSessionPrompts[i],
            priority: firstSessionPrompts.length - i,
          ),
      ],
    );
  }

  final out = <ArchivePrompt>[];
  void push(String type, String text, int priority) {
    if (text.trim().isEmpty) return;
    if (out.any((p) => p.text == text)) return;
    out.add(
      ArchivePrompt(
        id: 'ap-${out.length}',
        type: type,
        text: text,
        priority: priority,
      ),
    );
  }

  if (hasRecentChange) {
    push(
      'RECENT_CHANGE_PROMPT',
      strengthening
          ? 'This belief became stronger recently. Have you noticed that too?'
          : 'Something shifted in the archive recently. Does that match what you have noticed?',
      100,
    );
  }

  if (hasOpenQuestion) {
    push('OPEN_QUESTION_PROMPT', openUncertain, 90);
  }

  if (missingAreaLabel != null && missingAreaLabel.isNotEmpty) {
    push(
      'MISSING_AREA_PROMPT',
      'The archive has not heard much about $missingAreaLabel lately. What has been happening there?',
      80,
    );
  }

  final belief = beliefSnippet?.trim();
  push(
    'SUPPORT_PROMPT',
    belief != null && belief.isNotEmpty
        ? 'Did anything happen recently that supports this belief?'
        : 'Did anything happen recently that supports what you have been saying?',
    70,
  );
  push(
    'CHALLENGE_PROMPT',
    belief != null && belief.isNotEmpty
        ? 'Did anything happen recently that challenges this belief?'
        : 'Did anything happen recently that challenges what you have been saying?',
    60,
  );
  push('GENERAL_CAPTURE_PROMPT', generalCapture, 50);

  out.sort((a, b) => b.priority.compareTo(a.priority));
  return ArchivePromptSet(mode: 'archive_aware', prompts: out);
}

List<ArchivePrompt> pickArchiveDisplayPrompts(
  ArchivePromptSet set, {
  int refreshIndex = 0,
  int count = 3,
}) {
  if (set.prompts.length <= count) return set.prompts.take(count).toList();
  final start = refreshIndex % set.prompts.length;
  final picked = <ArchivePrompt>[];
  for (var i = 0; i < count; i++) {
    picked.add(set.prompts[(start + i) % set.prompts.length]);
  }
  return picked;
}

String buildPostSaveFollowUp({required bool beliefShifting}) {
  if (beliefShifting) {
    return 'Did this support or challenge the belief?';
  }
  return 'Anything else related to that?';
}
