import '../../models/journal_entry.dart';
import '../archive_evidence/archive_belief_thread_model.dart';
import '../archive_evidence/archive_evidence_heuristics.dart';
import '../archive_evidence/archive_pattern_copy_guard.dart';
import '../timeline/timeline_entry_display.dart';
import 'archive_thought_map_models.dart';

/// Attaches local saved-moment evidence to thought map nodes — no invented text.
abstract final class ArchiveThoughtMapEvidenceBuilder {
  ArchiveThoughtMapEvidenceBuilder._();

  static const maxSnippets = 3;
  static const minExcerptLength = 20;
  static const maxExcerptLength = 96;

  static ArchiveThoughtMapNode buildNode({
    required String suggestionId,
    required ArchiveThoughtMapNodeKind kind,
    required String label,
    required String value,
    required List<JournalEntry> eligible,
    required ArchiveEvidenceAnalysis analysis,
    required ArchiveBeliefThread thread,
  }) {
    final matched = _matchingEntries(
      kind: kind,
      eligible: eligible,
      analysis: analysis,
      thread: thread,
    );
    final snippets = matched
        .take(maxSnippets)
        .map(_snippetFromEntry)
        .where((s) => s.excerpt.length >= minExcerptLength)
        .toList();

    return ArchiveThoughtMapNode(
      id: '${suggestionId}_${kind.name}',
      kind: kind,
      label: label,
      value: value,
      supportingMomentCount: matched.length,
      snippets: snippets,
    );
  }

  static List<JournalEntry> _matchingEntries({
    required ArchiveThoughtMapNodeKind kind,
    required List<JournalEntry> eligible,
    required ArchiveEvidenceAnalysis analysis,
    required ArchiveBeliefThread thread,
  }) {
    final window = analysis.windowEntries.isNotEmpty
        ? analysis.windowEntries
        : eligible;

    bool matches(JournalEntry entry, bool Function(String lower) test) {
      final lower = resolveEntryDisplayText(entry).text.toLowerCase();
      if (ArchivePatternCopyGuard.isBlockedPatternText(lower)) return false;
      return lower.trim().length >= minExcerptLength && test(lower);
    }

    final matched = switch (kind) {
      ArchiveThoughtMapNodeKind.trigger => window.where(
          (e) => matches(
            e,
            (t) =>
                _contextKeywords.values
                    .expand((words) => words)
                    .any(t.contains) ||
                t.contains('capacity') ||
                t.contains('yes') ||
                t.contains('pressure'),
          ),
        ),
      ArchiveThoughtMapNodeKind.thought => window.where(
          (e) => matches(
            e,
            (t) =>
                analysis.repeatedPressurePhrases.any(
                  (phrase) => t.contains(phrase.split(' ').last),
                ) ||
                t.contains('pressure') ||
                t.contains('behind') ||
                t.contains('enough') ||
                t.contains('should') ||
                t.contains('guilty'),
          ),
        ),
      ArchiveThoughtMapNodeKind.behaviour => window.where(
          (e) => matches(
            e,
            (t) =>
                t.contains('said yes') ||
                t.contains('agreed') ||
                t.contains('capacity') ||
                t.contains('yes again'),
          ),
        ),
      ArchiveThoughtMapNodeKind.relief => window.where(
          (e) => matches(
            e,
            (t) =>
                t.contains('noticed') ||
                t.contains('earlier') ||
                t.contains('realized') ||
                t.contains('realised') ||
                t.contains('sooner') ||
                t.contains('softer'),
          ),
        ),
      ArchiveThoughtMapNodeKind.cost => window.where(
          (e) => matches(
            e,
            (t) =>
                t.contains('tired') ||
                t.contains('rest') ||
                t.contains('exhausted') ||
                t.contains('avoid') ||
                t.contains('burnout'),
          ),
        ),
      ArchiveThoughtMapNodeKind.alternative => window.where(
          (e) => matches(
            e,
            (t) {
              final testLine = thread.whatToTest.toLowerCase();
              if (testLine.contains('capacity') &&
                  (t.contains('capacity') || t.contains('yes'))) {
                return true;
              }
              if (testLine.contains('agree') &&
                  (t.contains('yes') || t.contains('agree'))) {
                return true;
              }
              if (testLine.contains('different') || testLine.contains('notice')) {
                return t.contains('different') || t.contains('notice');
              }
              return false;
            },
          ),
        ),
    };

    return matched.toList();
  }

  static ArchiveThoughtMapEvidenceSnippet _snippetFromEntry(JournalEntry entry) {
    final trimmed = resolveEntryDisplayText(entry).text.trim();
    if (ArchivePatternCopyGuard.isBlockedPatternText(trimmed)) {
      return ArchiveThoughtMapEvidenceSnippet(
        entryId: entry.id,
        excerpt: '',
        savedAt: entry.createdAt,
      );
    }
    final excerpt = trimmed.length <= maxExcerptLength
        ? trimmed
        : '${trimmed.substring(0, maxExcerptLength - 1).trim()}…';
    return ArchiveThoughtMapEvidenceSnippet(
      entryId: entry.id,
      excerpt: excerpt,
      savedAt: entry.createdAt,
    );
  }

  static const Map<String, List<String>> _contextKeywords = {
    'work': ['work', 'office', 'deadline', 'boss', 'project', 'job'],
    'family': ['family', 'kids', 'child', 'partner', 'parent', 'home'],
    'rest': ['rest', 'tired', 'sleep', 'exhausted', 'burnout'],
    'saying yes': ['yes', 'agree', 'help', 'capacity', 'commit'],
    'deadlines': ['deadline', 'due', 'late', 'overdue'],
    'money': ['money', 'bills', 'rent', 'pay', 'afford'],
    'health': ['health', 'sick', 'doctor', 'pain'],
    'relationships': ['friend', 'relationship', 'people', 'partner'],
  };
}
