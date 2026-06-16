import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_state_delta/archive_state_snapshot.dart';
import '../../storage/mobile_prefs_store.dart';
import 'belief_evolution_models.dart';
import 'belief_evolution_store.dart';

class BeliefEvolutionService {
  BeliefEvolutionService(this._store);

  final BeliefEvolutionStore _store;

  static BeliefEvolutionService fromPrefs(MobilePrefsStore prefs) {
    return BeliefEvolutionService(BeliefEvolutionStore(prefs));
  }

  Future<BeliefEvolutionState> loadState() => _store.load();

  Future<BeliefEvolutionState> refreshFromEntries({
    required List<JournalEntry> entries,
    ArchiveStateSnapshot? legacySnapshot,
  }) async {
    final currentText = archiveBeliefFromReflections(entries)?.trim() ?? '';
    if (currentText.isEmpty || !archiveHasMinimumEvidence(entries)) {
      return _store.load();
    }

    var state = await _store.load();
    final eligible = archiveEligibleEvidenceEntries(entries);
    final confidence = _confidenceFor(entries);

    if (state.versions.isEmpty) {
      final seedText = _seedFirstBelief(
        eligible: eligible,
        legacySnapshot: legacySnapshot,
        fallback: currentText,
      );
      final seedAt = eligible.isNotEmpty
          ? eligible.first.createdAt.toUtc().toIso8601String()
          : DateTime.now().toUtc().toIso8601String();
      final seedIds = _entryIdsUntil(
        eligible,
        DateTime.tryParse(seedAt) ?? DateTime.now(),
      );
      final first = BeliefVersionRecord(
        id: _newId('v1'),
        beliefText: seedText,
        confidence: confidence,
        recordedAt: seedAt,
        supportingEntryIds: seedIds,
      );
      state = state.copyWith(versions: [first]);
    }

    final last = state.versions.last;
    if (_normalize(last.beliefText) != _normalize(currentText)) {
      final recordedAt = DateTime.now().toUtc().toIso8601String();
      final since = DateTime.tryParse(last.recordedAt) ?? DateTime.now();
      final supporting = _entryIdsAfter(eligible, since);
      final next = BeliefVersionRecord(
        id: _newId('v${state.versions.length + 1}'),
        beliefText: currentText,
        confidence: confidence,
        recordedAt: recordedAt,
        supportingEntryIds: supporting.isNotEmpty
            ? supporting
            : _recentEntryIds(eligible, 3),
      );
      state = state.copyWith(versions: [...state.versions, next]);
    } else {
      final updated = last.copyWith(
        confidence: confidence,
        supportingEntryIds: _mergeIds(
          last.supportingEntryIds,
          _recentEntryIds(eligible, 5),
        ),
      );
      final versions = [...state.versions];
      versions[versions.length - 1] = updated;
      state = state.copyWith(versions: versions);
    }

    await _store.save(state);
    return state;
  }

  BeliefEvolutionTimeline buildTimeline({
    required BeliefEvolutionState state,
    required List<JournalEntry> entries,
  }) {
    if (state.versions.isEmpty) {
      return BeliefEvolutionTimeline(
        blocks: const [],
        firstBelief: null,
        currentBelief: null,
      );
    }

    final byId = {for (final e in entries) e.id: e};
    final blocks = <BeliefEvolutionBlock>[];

    for (final version in state.versions) {
      blocks.add(
        BeliefEvolutionBlock(
          version: version,
          evidence: _evidenceLines(version, byId),
        ),
      );
    }

    return BeliefEvolutionTimeline(
      blocks: blocks,
      firstBelief: state.firstBelief,
      currentBelief: state.currentBelief,
    );
  }

  /// Payload for a future POST /api/archive/belief-evolution sync.
  Map<String, dynamic> toSyncPayload(BeliefEvolutionState state) {
    return {
      'schemaVersion': state.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'evolution': state.toJson(),
    };
  }
}

String _normalize(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _newId(String prefix) =>
    '$prefix-${DateTime.now().millisecondsSinceEpoch}';

int _confidenceFor(List<JournalEntry> entries) {
  final count = archiveEvidenceReflectionCount(entries);
  if (count >= 8) return 85;
  if (count >= archiveMinEvidenceReflections) return 72;
  if (count >= 3) return 55;
  if (count >= 1) return 40;
  return 20;
}

String _seedFirstBelief({
  required List<JournalEntry> eligible,
  required ArchiveStateSnapshot? legacySnapshot,
  required String fallback,
}) {
  final legacy = legacySnapshot?.belief.trim() ?? '';
  if (legacy.isNotEmpty) return legacy;

  for (final e in eligible) {
    final obs = e.reflection.concreteObservation.trim();
    if (obs.length >= 16) return obs;
  }
  if (eligible.isNotEmpty) {
    final quote = eligible.first.transcript.trim();
    if (quote.length >= 16) {
      return quote.length <= 200 ? quote : '${quote.substring(0, 200).trim()}…';
    }
  }
  return fallback;
}

List<String> _entryIdsUntil(List<JournalEntry> eligible, DateTime end) {
  return eligible
      .where((e) => !e.createdAt.isAfter(end))
      .map((e) => e.id)
      .toList();
}

List<String> _entryIdsAfter(List<JournalEntry> eligible, DateTime after) {
  return eligible
      .where((e) => e.createdAt.isAfter(after))
      .map((e) => e.id)
      .toList();
}

List<String> _recentEntryIds(List<JournalEntry> eligible, int max) {
  if (eligible.isEmpty) return const [];
  final start = eligible.length > max ? eligible.length - max : 0;
  return eligible.sublist(start).map((e) => e.id).toList();
}

List<String> _mergeIds(List<String> existing, List<String> extra) {
  final out = <String>[];
  for (final id in [...existing, ...extra]) {
    if (id.isNotEmpty && !out.contains(id)) out.add(id);
  }
  return out;
}

List<BeliefEvidenceLine> _evidenceLines(
  BeliefVersionRecord version,
  Map<String, JournalEntry> byId,
) {
  final lines = <BeliefEvidenceLine>[];
  for (final id in version.supportingEntryIds.take(4)) {
    final entry = byId[id];
    if (entry == null) continue;
    lines.add(
      BeliefEvidenceLine(
        entryId: id,
        quote: _quoteForEntry(entry),
        dateLabel: _dateLabel(entry.createdAt),
      ),
    );
  }
  if (lines.isEmpty && byId.isNotEmpty) {
    final fallback = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final entry in fallback.take(2)) {
      lines.add(
        BeliefEvidenceLine(
          entryId: entry.id,
          quote: _quoteForEntry(entry),
          dateLabel: _dateLabel(entry.createdAt),
        ),
      );
    }
  }
  return lines;
}

String _quoteForEntry(JournalEntry entry) {
  final exact = entry.reflection.exactLanguagePattern.trim();
  if (exact.length >= 12) {
    return exact.length <= 140 ? exact : '${exact.substring(0, 140).trim()}…';
  }
  final t = entry.transcript.trim();
  if (t.isEmpty) return entry.reflection.concreteObservation.trim();
  final line = t.split('\n').first.trim();
  return line.length <= 140 ? line : '${line.substring(0, 140).trim()}…';
}

String _dateLabel(DateTime at) {
  final local = at.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
