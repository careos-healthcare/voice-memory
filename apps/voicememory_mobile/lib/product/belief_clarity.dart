import '../features/archive_beliefs/archive_belief_models.dart';
import 'consumer_ui_copy.dart';

/// User-facing pattern explanations for cards and detail screens.
abstract final class BeliefClarity {
  BeliefClarity._();

  static String quotedBelief(String statement) {
    final t = statement.trim();
    if (t.startsWith('"') && t.endsWith('"')) return t;
    return '"$t"';
  }

  static int reflectionCountFromSummary(String evidenceSummary) {
    final m = RegExp(r'(\d+)').firstMatch(evidenceSummary);
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }

  static String whyLine(ArchiveBeliefCardModel belief) {
    final n = reflectionCountFromSummary(belief.evidenceSummary);
    if (n > 0) {
      return 'You mentioned this in $n reflection${n == 1 ? '' : 's'}.';
    }
    return belief.evidenceSummary;
  }

  static String whyItMatters(ArchiveBeliefCardModel belief) {
    final s = belief.statement.toLowerCase();
    if (s.contains('avoid') ||
        s.contains('conversation') ||
        s.contains('conflict')) {
      return 'This pattern may be shaping relationships, work decisions, '
          'and difficult conversations.';
    }
    if (s.contains('prove') ||
        s.contains('achievement') ||
        s.contains('work') ||
        s.contains('behind')) {
      return 'This pattern may be shaping how you measure yourself, take on '
          'pressure, and set expectations.';
    }
    if (s.contains('ready') || s.contains('not yet')) {
      return 'This pattern may be shaping when you feel ready to act.';
    }
    return switch (belief.section) {
      ArchiveBeliefSection.emerging =>
        'Noticing this early can change how you respond before it settles in.',
      ArchiveBeliefSection.changing =>
        'As this shifts, the same situations may start to feel different.',
      ArchiveBeliefSection.hiddenPattern =>
        'Patterns like this often run quietly until you name them.',
      ArchiveBeliefSection.current =>
        'This pattern may be shaping daily choices and how you read your life.',
    };
  }

  static String archiveExplanation(
    ArchiveBeliefCardModel belief, {
    required int reflectionsAnalysed,
  }) {
    final n = reflectionCountFromSummary(belief.evidenceSummary);
    final count = n > 0 ? n : reflectionsAnalysed;
    final themes = _themeHint(belief.statement);
    if (themes != null) {
      return 'ArchiveMe noticed this across reflections about $themes.';
    }
    if (count > 0) {
      return 'ArchiveMe noticed this across $count '
          'reflection${count == 1 ? '' : 's'} in your own words.';
    }
    return belief.whyExplanation;
  }

  static String? _themeHint(String statement) {
    final s = statement.toLowerCase();
    if (s.contains('prove') || s.contains('achievement') || s.contains('work')) {
      return 'work, achievement, and self-worth';
    }
    if (s.contains('avoid') || s.contains('conversation')) {
      return 'relationships, tension, and hard conversations';
    }
    if (s.contains('ready')) {
      return 'readiness, risk, and change';
    }
    return null;
  }
}
