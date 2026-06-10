import 'daily_return_suggestion_model.dart';
import 'personal_return_prompt_engine.dart';
import 'pressure_check_in_option.dart';
import 'pressure_check_in_record.dart';
import 'pressure_personal_evidence_summary_engine.dart';

/// Builds the "Worth checking today" list from the user's own local evidence.
///
/// Pure and deterministic, no AI calls. Suggestions only ever reference what
/// the user actually logged: the most recent pressure option first, then
/// repeated terms from the personal evidence summary, then repeated contexts
/// and recent fear notes. Never homework, never "you should".
class DailyReturnSuggestionEngine {
  const DailyReturnSuggestionEngine();

  static const _evidenceEngine = PressurePersonalEvidenceSummaryEngine();

  static const int maxSuggestions = 4;
  static const int minSuggestions = 2;

  /// Evidence snippets stay short — the user's words, never a wall of text.
  static const int maxSnippetLength = 80;

  DailyReturnSuggestionSet build(List<PressureCheckInRecord> records) {
    if (records.isEmpty) return DailyReturnSuggestionSet.empty;

    final sorted = [...records]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Each user-written note is shown at most once across the whole card.
    final usedSnippets = <String>{};
    String? claim(String? raw) {
      final snippet = _trimmedSnippet(raw);
      if (snippet == null || !usedSnippets.add(snippet)) return null;
      return snippet;
    }

    final candidates = <DailyReturnSuggestion>[
      // Recent evidence first: the option from the latest entry.
      ..._recentOptionSuggestion(sorted, claim),
      ..._termSuggestions(records, sorted, claim),
      ..._repeatedContextSuggestion(records, sorted, claim),
      ..._recentFearSuggestion(sorted, claim),
      // Gentle filler so a single sparse entry still yields two rows.
      const DailyReturnSuggestion(
        id: 'todays_pressure',
        title: "Today's pressure",
        prompt: 'What did the pressure make you do today, '
            'even something small?',
        reason: 'One honest sentence is enough.',
      ),
    ];

    final suggestions = _dedupe(candidates).take(maxSuggestions).toList();
    return DailyReturnSuggestionSet(
      suggestions: suggestions,
      personalized: true,
      label: DailyReturnSuggestionSet.heading,
    );
  }

  List<DailyReturnSuggestion> _recentOptionSuggestion(
    List<PressureCheckInRecord> newestFirst,
    String? Function(String?) claim,
  ) {
    final latest = newestFirst.first;
    final option = latest.option;
    final prompt = PersonalReturnPromptEngine.optionEdgePrompt(option);
    if (option == null || prompt == null) return const [];
    return [
      DailyReturnSuggestion(
        id: 'recent_option_${option.id}',
        title: _optionTitle(option),
        prompt: prompt,
        reason: 'This came up in a recent pressure moment.',
        evidenceSnippet: claim(latest.fear ?? latest.stopCostNote),
      ),
    ];
  }

  /// Repeated terms from the personal evidence summary (3+ entries).
  List<DailyReturnSuggestion> _termSuggestions(
    List<PressureCheckInRecord> records,
    List<PressureCheckInRecord> newestFirst,
    String? Function(String?) claim,
  ) {
    final summary = _evidenceEngine.build(records);
    if (!summary.hasSummary || summary.evidenceTerms.isEmpty) return const [];
    final terms = summary.evidenceTerms;
    return [
      DailyReturnSuggestion(
        id: 'term_${terms.first}',
        title: 'What ${terms.first} pressure made you do',
        prompt: 'What did ${terms.first} pressure make you '
            'rush or hide today?',
        reason: 'You mentioned this before.',
        sourceTerms: [terms.first],
        evidenceSnippet: claim(_noteMentioning(newestFirst, terms.first)),
      ),
      if (terms.length >= 2)
        DailyReturnSuggestion(
          id: 'term_${terms[1]}',
          title: 'Where ${terms[1]} made you overdo it',
          prompt: 'What did ${terms[1]} pressure make you overdo today?',
          reason: '${_capitalize(terms[1])} appeared across recent entries.',
          sourceTerms: [terms[1]],
          evidenceSnippet: claim(_noteMentioning(newestFirst, terms[1])),
        ),
    ];
  }

  /// A context label seen in 2+ entries, even before the summary kicks in.
  List<DailyReturnSuggestion> _repeatedContextSuggestion(
    List<PressureCheckInRecord> records,
    List<PressureCheckInRecord> newestFirst,
    String? Function(String?) claim,
  ) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final context in record.contexts) {
        final label = context.label.toLowerCase();
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    String? best;
    var bestCount = 1; // require >= 2 to call it repeated.
    final labels = counts.keys.toList()..sort();
    for (final label in labels) {
      if (counts[label]! > bestCount) {
        bestCount = counts[label]!;
        best = label;
      }
    }
    if (best == null) return const [];
    return [
      DailyReturnSuggestion(
        id: 'context_$best',
        title: 'Where $best made you overdo it',
        prompt: 'What did $best pressure make you overdo today?',
        reason: '${_capitalize(best)} appeared across recent entries.',
        sourceTerms: [best],
        evidenceSnippet: claim(_noteForContext(newestFirst, best)),
      ),
    ];
  }

  /// The most recent entry that carries a written fear note.
  List<DailyReturnSuggestion> _recentFearSuggestion(
    List<PressureCheckInRecord> newestFirst,
    String? Function(String?) claim,
  ) {
    for (final record in newestFirst) {
      final fear = record.fear?.trim() ?? '';
      if (fear.isEmpty) continue;
      return [
        DailyReturnSuggestion(
          id: 'recent_fear',
          title: 'What you were afraid would happen',
          prompt: 'What were you afraid would happen if you stopped today?',
          reason: DailyReturnSuggestionSet.archiveNoticedReason,
          evidenceSnippet: claim(fear),
        ),
      ];
    }
    return const [];
  }

  /// The newest user-written note that actually mentions [term] —
  /// never attributed across topics, never fabricated.
  String? _noteMentioning(
    List<PressureCheckInRecord> newestFirst,
    String term,
  ) {
    final needle = term.toLowerCase();
    for (final record in newestFirst) {
      for (final note in [record.fear, record.stopCostNote]) {
        if (note != null && note.toLowerCase().contains(needle)) return note;
      }
    }
    return null;
  }

  /// The newest user-written note from an entry logged with [contextLabel].
  String? _noteForContext(
    List<PressureCheckInRecord> newestFirst,
    String contextLabel,
  ) {
    for (final record in newestFirst) {
      final labels =
          record.contexts.map((c) => c.label.toLowerCase()).toList();
      if (!labels.contains(contextLabel)) continue;
      final note = record.fear ?? record.stopCostNote;
      if (note != null && note.trim().isNotEmpty) return note;
    }
    return null;
  }

  /// Trims and caps a user note; null when there is nothing safe to show.
  String? _trimmedSnippet(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= maxSnippetLength) return trimmed;
    return '${trimmed.substring(0, maxSnippetLength - 1).trimRight()}…';
  }

  /// Drops duplicate ids and duplicate prompts, keeping first (highest
  /// priority) occurrences.
  List<DailyReturnSuggestion> _dedupe(List<DailyReturnSuggestion> candidates) {
    final seenIds = <String>{};
    final seenPrompts = <String>{};
    return [
      for (final s in candidates)
        if (seenIds.add(s.id) && seenPrompts.add(s.prompt)) s,
    ];
  }

  /// Curiosity/action titles — they imply a useful reflection, not a task.
  String _optionTitle(PressureCheckInOption option) {
    switch (option) {
      case PressureCheckInOption.couldNotStop:
        return 'Where stopping felt unsafe';
      case PressureCheckInOption.didMoreToNotFeelBehind:
        return 'What you did to avoid feeling behind';
      case PressureCheckInOption.hadToProveEnough:
        return 'What you did to prove enough';
      case PressureCheckInOption.guiltyResting:
        return 'The rest you talked yourself out of';
      case PressureCheckInOption.keptGoingToFeelProductive:
        return 'What you kept doing after it stopped helping';
    }
  }

  static String _capitalize(String term) =>
      term.isEmpty ? term : term[0].toUpperCase() + term.substring(1);
}
