import '../../product/consumer_ui_copy.dart';
import 'personal_return_prompt_model.dart';
import 'pressure_check_in_option.dart';
import 'pressure_check_in_record.dart';
import 'pressure_personal_evidence_summary_engine.dart';

/// Builds Record-screen starter prompts from the user's own local evidence.
///
/// Pure and deterministic. Prompts only ever reference what the user actually
/// logged — repeated terms, contexts, and the last pressure option — and ask
/// sharper questions about action, cost, fear, and triggers ("What did that
/// pressure make you do today?"), never asserting ("you always"). With no
/// evidence it falls back to the generic prompts.
class PersonalReturnPromptEngine {
  const PersonalReturnPromptEngine();

  static const _evidenceEngine = PressurePersonalEvidenceSummaryEngine();

  /// Shown at most this many prompts.
  static const int maxPrompts = 4;

  static const String _genericFallbackLine =
      'Start with whatever happened today — one honest sentence is enough.';

  static const String _smallMomentPrompt =
      'What did the pressure make you do today, even something small?';

  static String _capitalize(String term) =>
      term.isEmpty ? term : term[0].toUpperCase() + term.substring(1);

  PersonalReturnPromptSet build(List<PressureCheckInRecord> records) {
    if (records.isEmpty) {
      return const PersonalReturnPromptSet(
        prompts: ConsumerUiCopy.recordStarterPrompts,
        personalized: false,
        emptyStateFallback: _genericFallbackLine,
      );
    }

    if (records.length >= 3) {
      final summary = _evidenceEngine.build(records);
      if (summary.hasSummary && summary.evidenceTerms.isNotEmpty) {
        return _evidenceBased(records, summary.evidenceTerms);
      }
    }

    // 1–2 entries, or 3+ without repeated evidence: gentle continuation.
    return _gentleContinuation(records);
  }

  /// Prompts built from repeated terms across 3+ entries.
  PersonalReturnPromptSet _evidenceBased(
    List<PressureCheckInRecord> records,
    List<String> terms,
  ) {
    final prompts = <String>[];

    if (terms.length >= 2) {
      prompts.add(
        'You mentioned ${terms[0]} and ${terms[1]} before. '
        'What did that pressure make you do today?',
      );
    } else {
      prompts.add(
        'You mentioned ${terms.first} before. '
        'What did that pressure make you do today?',
      );
    }
    prompts.add(
      '${_capitalize(terms.first)} pressure has shown up before. '
      'What did it make you rush, overdo, or avoid today?',
    );

    final optionLine = _optionLine(_latestOption(records));
    if (optionLine != null) prompts.add(optionLine);

    final contextLabel = _topRepeatedContextLabel(records);
    if (contextLabel != null) {
      // Alternate the context question with entry count so the prompt area
      // doesn't read identically every day.
      prompts.add(
        records.length.isOdd
            ? 'You logged $contextLabel pressure before. '
                'What did it cost you today?'
            : 'This came up before around $contextLabel. '
                'What happened right before it started today?',
      );
    }

    return PersonalReturnPromptSet(
      prompts: _capped(prompts),
      personalized: true,
      sourceTerms: terms,
    );
  }

  /// 1–2 entries: continue from the last logged moment — sharper questions,
  /// still gentle.
  PersonalReturnPromptSet _gentleContinuation(
    List<PressureCheckInRecord> records,
  ) {
    final prompts = <String>[];
    final sourceTerms = <String>[];

    final option = _latestOption(records);
    final optionLine = _optionLine(option);
    if (optionLine != null) {
      prompts.add(optionLine);
      sourceTerms.add(_optionTerm(option)!);
    } else {
      prompts.add(
        'You logged a pressure moment before. '
        'What did that pressure make you do today?',
      );
    }

    final contextLine = _repeatedContextLine(records, requireRepeat: false);
    if (contextLine != null) {
      prompts.add(contextLine);
      sourceTerms.add(_latestContextLabel(records)!);
    }

    prompts
      ..add(_smallMomentPrompt)
      ..add('What did you avoid today, if anything?');

    return PersonalReturnPromptSet(
      prompts: _capped(prompts),
      personalized: true,
      sourceTerms: sourceTerms,
    );
  }

  List<String> _capped(List<String> prompts) {
    final seen = <String>{};
    final unique = [
      for (final p in prompts)
        if (seen.add(p)) p,
    ];
    if (unique.length < 3) unique.add(_smallMomentPrompt);
    return unique.take(maxPrompts).toList();
  }

  PressureCheckInOption? _latestOption(List<PressureCheckInRecord> records) {
    final sorted = [...records]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.option;
  }

  /// Continuation line for the last logged option — asks about fear, cost,
  /// or action; never asserts.
  String? _optionLine(PressureCheckInOption? option) {
    switch (option) {
      case PressureCheckInOption.couldNotStop:
        return 'Last time, stopping felt difficult. '
            'What were you afraid would happen if you stopped today?';
      case PressureCheckInOption.didMoreToNotFeelBehind:
        return 'Last time, feeling behind pushed you to do more. '
            'What did it make you take on today?';
      case PressureCheckInOption.hadToProveEnough:
        return 'Last time, proving yourself came up. '
            'What did you do today to feel like enough?';
      case PressureCheckInOption.guiltyResting:
        return 'Last time, resting came with guilt. '
            'What did that guilt stop you from doing today?';
      case PressureCheckInOption.keptGoingToFeelProductive:
        return 'Last time, you kept going to feel productive. '
            'What did it cost you today?';
      case null:
        return null;
    }
  }

  String? _optionTerm(PressureCheckInOption? option) {
    switch (option) {
      case PressureCheckInOption.couldNotStop:
        return 'stopping';
      case PressureCheckInOption.didMoreToNotFeelBehind:
        return 'feeling behind';
      case PressureCheckInOption.hadToProveEnough:
        return 'proving yourself';
      case PressureCheckInOption.guiltyResting:
        return 'guilt about resting';
      case PressureCheckInOption.keptGoingToFeelProductive:
        return 'needing to feel productive';
      case null:
        return null;
    }
  }

  /// "You logged evening pressure before. What did it cost you today?"
  /// With [requireRepeat], the context must appear in 2+ entries.
  String? _repeatedContextLine(
    List<PressureCheckInRecord> records, {
    bool requireRepeat = true,
  }) {
    final label = requireRepeat
        ? _topRepeatedContextLabel(records)
        : _latestContextLabel(records);
    if (label == null) return null;
    return 'You logged $label pressure before. What did it cost you today?';
  }

  String? _latestContextLabel(List<PressureCheckInRecord> records) {
    final sorted = [...records]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final record in sorted) {
      final contexts = record.contexts;
      if (contexts.isNotEmpty) return contexts.first.label.toLowerCase();
    }
    return null;
  }

  String? _topRepeatedContextLabel(List<PressureCheckInRecord> records) {
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
      final count = counts[label]!;
      if (count > bestCount) {
        bestCount = count;
        best = label;
      }
    }
    return best;
  }
}
