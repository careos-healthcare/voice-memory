import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../post_save_insight/selected_signal_model.dart';
import 'signal_evidence_model.dart';

/// Builds a signal evidence trail from real journal entries — no invented evidence.
class SignalEvidenceEngine {
  const SignalEvidenceEngine();

  static const int _excerptMaxChars = 88;

  SignalEvidenceTrail build({
    required SelectedSignalRecord? signal,
    required List<JournalEntry> entries,
  }) {
    if (signal == null) {
      return const SignalEvidenceTrail(
        items: [],
        clarityPrompt: '',
        nextEvidencePrompt: '',
        needsMoreEvidence: true,
      );
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final items = <SignalEvidenceItem>[];
    final seen = <String>{};

    void addItem(JournalEntry entry, SignalEvidenceRelation relation, String tag) {
      if (seen.contains(entry.id)) return;
      seen.add(entry.id);
      final excerpt = _safeExcerpt(entry);
      if (excerpt.isEmpty) return;
      items.add(
        SignalEvidenceItem(
          entryId: entry.id,
          date: entry.createdAt,
          excerpt: excerpt,
          tag: tag,
          relation: relation,
        ),
      );
    }

    if (signal.entryId != null) {
      final origin = eligible.where((e) => e.id == signal.entryId).firstOrNull;
      if (origin != null) {
        addItem(
          origin,
          SignalEvidenceRelation.supports,
          signal.evidenceChips.isNotEmpty
              ? signal.evidenceChips.first
              : 'From your moment',
        );
      }
    }

    for (final entry in eligible) {
      if (seen.contains(entry.id)) continue;
      final relation = _relationFor(entry, signal);
      if (relation == null) continue;
      final tag = _tagFor(entry, signal);
      addItem(entry, relation, tag);
    }

    items.sort((a, b) => a.date.compareTo(b.date));

    return SignalEvidenceTrail(
      items: items,
      clarityPrompt: signal.wouldConfirm?.trim().isNotEmpty == true
          ? signal.wouldConfirm!
          : 'One more moment on the same theme would sharpen this.',
      nextEvidencePrompt: signal.nextPrompt,
      needsMoreEvidence: items.length < 2,
    );
  }

  SignalEvidenceRelation? _relationFor(
    JournalEntry entry,
    SelectedSignalRecord signal,
  ) {
    final text = _entryText(entry).toLowerCase();
    if (text.isEmpty) return null;

    if (_matchesContradict(text, signal)) {
      return SignalEvidenceRelation.mightContradict;
    }

    if (_matchesSupport(text, signal)) {
      return SignalEvidenceRelation.supports;
    }

    if (signal.categoryId.isNotEmpty &&
        _categoryHints(signal.categoryId)
            .any((hint) => text.contains(hint.toLowerCase()))) {
      return SignalEvidenceRelation.unclear;
    }

    return null;
  }

  bool _matchesSupport(String text, SelectedSignalRecord signal) {
    for (final chip in signal.evidenceChips) {
      if (chip.trim().length >= 3 &&
          text.contains(chip.trim().toLowerCase())) {
        return true;
      }
    }
    final titleWords = signal.title
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 4)
        .take(3);
    var hits = 0;
    for (final w in titleWords) {
      if (text.contains(w)) hits++;
    }
    return hits >= 2;
  }

  bool _matchesContradict(String text, SelectedSignalRecord signal) {
    final hint = signal.wouldContradict?.trim() ?? '';
    if (hint.isEmpty) return false;
    final tokens = hint
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 3)
        .take(6);
    var hits = 0;
    for (final t in tokens) {
      if (text.contains(t)) hits++;
    }
    return hits >= 2;
  }

  String _tagFor(JournalEntry entry, SelectedSignalRecord signal) {
    for (final chip in signal.evidenceChips) {
      if (_entryText(entry).toLowerCase().contains(chip.toLowerCase())) {
        return chip;
      }
    }
    return signal.categoryId.isNotEmpty ? signal.categoryId : 'Moment';
  }

  String _safeExcerpt(JournalEntry entry) {
    final summary = entry.reflectionSummary.trim();
    if (summary.length >= 12) {
      return _truncate(summary);
    }
    final transcript = entry.transcript.trim();
    if (transcript.length >= ArchiveEvidenceGuard.minimumTranscriptChars) {
      return _truncate(transcript);
    }
    return '';
  }

  String _entryText(JournalEntry entry) {
    final summary = entry.reflectionSummary.trim();
    if (summary.isNotEmpty) return summary;
    return entry.transcript.trim();
  }

  String _truncate(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= _excerptMaxChars) return cleaned;
    return '${cleaned.substring(0, _excerptMaxChars - 1).trim()}…';
  }

  List<String> _categoryHints(String categoryId) {
    switch (categoryId) {
      case 'pressure':
        return const ['pressure', 'yes', 'overwhelmed', 'rushed'];
      case 'responsibility':
        return const ['responsible', 'should', 'carry', 'fix'];
      case 'relationship':
        return const ['disappoint', 'someone', 'relationship', 'conflict'];
      case 'lighter':
        return const ['lighter', 'easier', 'relief', 'calm'];
      default:
        return const [];
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
