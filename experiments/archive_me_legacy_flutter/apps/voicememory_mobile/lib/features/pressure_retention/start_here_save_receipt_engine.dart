import '../../billing/paywall_source.dart';
import 'daily_return_suggestion_model.dart';
import 'pressure_check_in_option.dart';
import 'start_here_save_receipt_model.dart';

/// Builds the post-save "Saved to your archive" receipt.
///
/// Pure and deterministic. Only produces a receipt when the saved recording
/// started from Start here today or a Daily Suggestion — generic prompt saves
/// never get one. Connected terms come from the tapped suggestion only
/// (its option, source terms, snippet, title), so the receipt never claims
/// connections the user has not actually made.
class StartHereSaveReceiptEngine {
  const StartHereSaveReceiptEngine();

  static const int maxConnectedTerms = 3;

  /// Words too generic to be a meaningful personal connection on their own.
  static const Set<String> genericTerms = {
    'archive',
    'pressure',
    'today',
    'recording',
    'prompt',
    'suggestion',
    'thing',
    'something',
  };

  /// Returns null for anything that was not a suggestion-sourced save.
  StartHereSaveReceipt? build({
    required PaywallSource? source,
    required DailyReturnSuggestion? suggestion,
  }) {
    if (source == null ||
        (source != PaywallSource.startHereToday &&
            source != PaywallSource.dailySuggestion)) {
      return null;
    }
    if (suggestion == null) return null;
    return StartHereSaveReceipt(
      connectedTerms: _connectedTerms(suggestion),
      paywallSource: source,
    );
  }

  List<String> _connectedTerms(DailyReturnSuggestion suggestion) {
    final terms = <String>[];

    void add(String? candidate) {
      if (terms.length >= maxConnectedTerms) return;
      final cleaned = candidate?.trim();
      if (cleaned == null || cleaned.isEmpty) return;
      if (_isGeneric(cleaned)) return;
      if (terms.any((t) => t.toLowerCase() == cleaned.toLowerCase())) return;
      terms.add(cleaned);
    }

    // 1. The pressure option behind a recent-moment suggestion reads as the
    //    most personal phrase-like label.
    add(_optionPhrase(suggestion.id));

    // 2. Source terms become "<term> pressure" phrases.
    for (final term in suggestion.sourceTerms) {
      final t = term.trim().toLowerCase();
      if (t.isEmpty || genericTerms.contains(t)) continue;
      add(t.contains('pressure') ? t : '$t pressure');
    }

    // 3. The user's own words, when a snippet exists.
    add(_snippetTerm(suggestion.evidenceSnippet));

    // 4. Fall back to the suggestion title so the receipt is never bare.
    if (terms.isEmpty) add(_titleTerm(suggestion.title));

    return terms;
  }

  /// Phrase-like label for option-backed suggestions
  /// (ids look like `recent_option_<optionId>`).
  String? _optionPhrase(String suggestionId) {
    const prefix = 'recent_option_';
    if (!suggestionId.startsWith(prefix)) return null;
    final option = PressureCheckInOption.fromId(
      suggestionId.substring(prefix.length),
    );
    switch (option) {
      case PressureCheckInOption.couldNotStop:
        return 'stopping felt unsafe';
      case PressureCheckInOption.didMoreToNotFeelBehind:
        return 'avoiding feeling behind';
      case PressureCheckInOption.hadToProveEnough:
        return 'proving you were enough';
      case PressureCheckInOption.guiltyResting:
        return 'guilt about resting';
      case PressureCheckInOption.keptGoingToFeelProductive:
        return 'needing to feel productive';
      case null:
        return null;
    }
  }

  /// Short label from the user's own snippet — already trimmed/capped by the
  /// suggestion engine, but kept chip-sized here.
  String? _snippetTerm(String? snippet) {
    final cleaned = snippet?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    if (cleaned.length <= 40) return cleaned;
    return '${cleaned.substring(0, 37).trimRight()}…';
  }

  String? _titleTerm(String title) {
    final cleaned = title.trim();
    if (cleaned.isEmpty) return null;
    return cleaned[0].toLowerCase() + cleaned.substring(1);
  }

  /// True when the candidate carries no meaning beyond generic words.
  bool _isGeneric(String candidate) {
    final words = candidate
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty);
    return words.every(genericTerms.contains);
  }
}
