import 'package:archiveme_mobile/models/ambient_context.dart';

/// Why a stored moment was chosen for the current context.
enum ActionableMemoryMatch { words, place, calendar, timeOfDay }

/// What the person is doing now. The pipeline does not read sensors itself.
class ActionableMemoryContext {
  const ActionableMemoryContext({
    required this.now,
    this.locality,
    this.calendarTitle,
    this.focusTerms = const [],
  });

  factory ActionableMemoryContext.fromAmbient({
    required DateTime now,
    AmbientContext? ambient,
    String? currentNote,
  }) {
    return ActionableMemoryContext(
      now: now,
      locality: ambient?.locality,
      calendarTitle: ambient?.calendarTitle,
      focusTerms: actionableMemoryTerms(currentNote),
    );
  }

  final DateTime now;
  final String? locality;
  final String? calendarTitle;
  final List<String> focusTerms;

  List<String> get calendarTerms => actionableMemoryTerms(calendarTitle);
}

/// One historical row the query judged relevant.
class ActionableMemoryHit {
  const ActionableMemoryHit({
    required this.entryId,
    required this.excerpt,
    required this.createdAt,
    required this.score,
    required this.match,
  });

  final String entryId;
  final String excerpt;
  final DateTime createdAt;
  final int score;
  final ActionableMemoryMatch match;
}

/// Request a live GPT-5 client would send. The stub never transmits it.
class Gpt5MemorySynthesisRequest {
  const Gpt5MemorySynthesisRequest({
    required this.model,
    required this.instruction,
    required this.moments,
  });

  static const modelId = 'gpt-5';

  final String model;
  final String instruction;
  final List<Map<String, String>> moments;
}

/// Local notification copy plus the request prepared for a later client.
class ActionableMemoryDraft {
  const ActionableMemoryDraft({
    required this.title,
    required this.body,
    required this.sourceEntryIds,
    required this.request,
    required this.readyForRemoteSynthesis,
  });

  final String title;
  final String body;
  final List<String> sourceEntryIds;
  final Gpt5MemorySynthesisRequest request;

  /// True only when the GPT-5 synthesis flag is on. The stub still stays local.
  final bool readyForRemoteSynthesis;
}

/// Push payload. [sourceEntryIds] is the trail a tap can open.
class ActionableMemoryNotification {
  const ActionableMemoryNotification({
    required this.title,
    required this.body,
    required this.sourceEntryIds,
  });

  final String title;
  final String body;
  final List<String> sourceEntryIds;

  String? get leadEntryId =>
      sourceEntryIds.isEmpty ? null : sourceEntryIds.first;
}

/// Words long enough to match a stored moment.
List<String> actionableMemoryTerms(String? text) {
  if (text == null) return const [];
  final seen = <String>{};
  final terms = <String>[];
  for (final raw in text.toLowerCase().split(RegExp('[^a-z0-9]+'))) {
    if (raw.length < 3 || _stopWords.contains(raw) || !seen.add(raw)) {
      continue;
    }
    terms.add(raw);
    if (terms.length == 8) break;
  }
  return terms;
}

const _stopWords = {
  'the',
  'and',
  'for',
  'you',
  'with',
  'this',
  'that',
  'from',
  'have',
  'was',
  'were',
  'are',
};
