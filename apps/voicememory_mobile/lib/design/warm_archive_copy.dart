import '../features/discover/discover_models.dart';
import '../features/living_archive/living_archive_copy.dart';
import '../features/living_archive/living_archive_models.dart';

/// Reflective, human-facing pattern language — not analytics tone.
abstract final class WarmArchiveCopy {
  WarmArchiveCopy._();

  static const String contradictionConcept = "Something doesn't quite fit";
  static const String themeConcept = 'Something you return to';
  static const String beliefConcept = 'A story you may be telling yourself';
  static const String confidenceConcept = 'How strongly this appears';
  static const String challengeSectionTitle = 'SOMETHING WORTH QUESTIONING';
  static const String archiveChangedMindSectionTitle =
      'ARCHIVEME CHANGED ITS READ';

  static const String beliefSectionTitle = 'A STORY YOU MAY BE TELLING YOURSELF';
  static const String beliefChangesSectionTitle = 'STORIES THAT SHIFTED';
  static const String themesSectionTitle = 'SOMETHING YOU RETURN TO';
  static const String contradictionsSectionTitle =
      "SOMETHING THAT DOESN'T QUITE FIT";
  static const String topThemesSectionTitle = 'SOMETHING YOU RETURN TO';

  static const String contradictionsLead =
      'Two reflections pull in different directions — worth sitting with, not fixing.';

  static const String beliefUnderReviewSectionTitle =
      'A STORY UNDER REVIEW';

  /// User-facing confidence movement (no percent deltas).
  static String confidenceShiftPhrase({
    required int prior,
    required int current,
  }) {
    final delta = current - prior;
    if (delta <= -LivingArchiveCopy.minConfidenceChangePercent) {
      return 'ArchiveMe is less certain about this than before.';
    }
    if (delta >= LivingArchiveCopy.minConfidenceChangePercent) {
      return 'ArchiveMe feels more certain about this than before.';
    }
    return 'This appears about as strongly as before.';
  }

  static String confidenceStrengthLine(int percent) =>
      '$confidenceConcept: $percent%';

  static String confidenceStrengthSemantics(int percent) =>
      '$confidenceConcept $percent percent';

  static String beliefStrengtheningSummary(String beliefQuote) =>
      'You keep mentioning “$beliefQuote” in recent reflections.';

  static String beliefWeakeningSummary(String beliefQuote) =>
      'You mention “$beliefQuote” less in recent recordings than you used to.';

  static String themeReturningMoreOften(String themeLabel) =>
      "You've been returning to $themeLabel more often.";

  static String themeReturningLessOften(String themeLabel) =>
      "You've been returning to $themeLabel less often.";

  static String archiveChangedMindConfidenceSummary({String? beliefSnippet}) {
    if (beliefSnippet != null && beliefSnippet.isNotEmpty) {
      return 'ArchiveMe is less certain about “$beliefSnippet” than it was '
          'when your earlier recordings shaped this story.';
    }
    return 'ArchiveMe is less certain about this than before.';
  }

  static String beliefChangeNarrative({
    required String priorLabel,
    required int priorPercent,
    required String currentLabel,
    required int currentPercent,
  }) {
    if (priorPercent == currentPercent) {
      return confidenceShiftPhrase(prior: priorPercent, current: currentPercent);
    }
    if (currentPercent > priorPercent) {
      return 'ArchiveMe leans toward this more than it did $priorLabel.';
    }
    return 'ArchiveMe leans toward this less than it did $priorLabel.';
  }

  static String beliefTrendLabel(BeliefConfidenceTrend trend) {
    return switch (trend) {
      BeliefConfidenceTrend.rising => 'Feels more certain lately',
      BeliefConfidenceTrend.falling => 'Feels less certain lately',
      BeliefConfidenceTrend.stable => 'Holding steady lately',
    };
  }

  static String themeTrendBrief(ThemeTrendDirection direction) {
    return switch (direction) {
      ThemeTrendDirection.up => 'coming up more lately',
      ThemeTrendDirection.down => 'showing up less lately',
      ThemeTrendDirection.flat => 'steady lately',
    };
  }

  static String formatWhatChangedLine(WhatChangedTodayLine line) {
    if (line.displayText != null && line.displayText!.isNotEmpty) {
      return line.displayText!;
    }
    return _legacyWhatChangedLine(line);
  }

  static String _legacyWhatChangedLine(WhatChangedTodayLine line) {
    final label = line.label.toLowerCase();
    if (label == 'confidence' || label == confidenceConcept.toLowerCase()) {
      final prior = _parsePercent(line.before);
      final current = _parsePercent(line.after);
      if (prior != null && current != null) {
        return confidenceShiftPhrase(prior: prior, current: current);
      }
    }
    if (label.contains('mention') || label.contains('reference')) {
      final before = int.tryParse(line.before);
      final after = int.tryParse(line.after);
      if (before != null && after != null) {
        final theme = _themeFromMentionLabel(line.label);
        if (after > before) return themeReturningMoreOften(theme);
        if (after < before) return themeReturningLessOften(theme);
      }
    }
    return '${line.label}: ${line.before} → ${line.after}';
  }

  static int? _parsePercent(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('%')) {
      return int.tryParse(trimmed.substring(0, trimmed.length - 1));
    }
    return int.tryParse(trimmed);
  }

  static String _themeFromMentionLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.startsWith('approval')) return 'approval';
    if (lower.startsWith('work')) return 'work';
    final cleaned = label
        .replaceAll(RegExp(r'\s*(mentions|references)\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return 'this';
    return cleaned[0].toLowerCase() + cleaned.substring(1);
  }
}
