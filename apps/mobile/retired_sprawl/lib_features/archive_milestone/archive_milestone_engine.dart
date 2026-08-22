import 'package:archiveme_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Shown when no snapshot- or delta-backed archive shifts exist.
const String archiveMilestonesEmptyCopy =
    'No meaningful archive shifts detected yet.';

/// Archive milestones — history moments backed by stored archive state (not counts).
class ArchiveMilestone {
  ArchiveMilestone({
    required this.id,
    required this.type,
    required this.title,
    required this.explanation,
    required this.periodLabel,
    required this.occurredAt,
  });

  final String id;
  final String type;
  final String title;
  final String explanation;
  final String periodLabel;
  final DateTime occurredAt;
}

class ArchiveMilestonesView {
  ArchiveMilestonesView({required this.milestones, this.latest});

  final List<ArchiveMilestone> milestones;
  final ArchiveMilestone? latest;

  bool get hasMeaningfulShifts => milestones.isNotEmpty;
}

ArchiveMilestonesView buildArchiveMilestones({
  required List<JournalEntry> entries,
  required String currentBeliefText,
  ArchiveStateDeltaView? delta,
  ArchiveStateSnapshot? baseline,
}) {
  final list = <ArchiveMilestone>[];
  final seenTypes = <String>{};

  void add({
    required String type,
    required String title,
    required String explanation,
    required DateTime occurredAt,
  }) {
    if (seenTypes.contains(type)) return;
    seenTypes.add(type);
    list.add(
      ArchiveMilestone(
        id: 'ms-$type-${occurredAt.millisecondsSinceEpoch}',
        type: type,
        title: title,
        explanation: explanation,
        periodLabel: _formatPeriodLabel(occurredAt),
        occurredAt: occurredAt,
      ),
    );
  }

  final eligible = entries.where((e) => e.transcript.trim().isNotEmpty).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  if (eligible.isEmpty || baseline == null) {
    return ArchiveMilestonesView(milestones: list);
  }

  final occurredAt =
      DateTime.tryParse(baseline.timestamp) ??
      eligible.last.createdAt.toLocal();

  final priorBelief = baseline.belief.trim();
  final nowBelief = currentBeliefText.trim();
  if (priorBelief.isNotEmpty &&
      nowBelief.isNotEmpty &&
      priorBelief != nowBelief) {
    add(
      type: 'FIRST_BELIEF_CHANGE',
      title: 'Belief shifted',
      explanation:
          'Since your last visit, the archive’s working belief changed: '
          '“${_truncate(priorBelief)}” → “${_truncate(nowBelief)}”.',
      occurredAt: occurredAt,
    );
  }

  if (delta != null && delta.hasChanges) {
    for (final row in delta.rows) {
      switch (row.label) {
        case 'Reputation':
          add(
            type: 'ARCHIVE_CHANGED_ITS_MIND',
            title: 'Archive reputation shifted',
            explanation:
                'Stored archive reputation moved from ${row.then} to ${row.now} '
                '(${row.difference}).',
            occurredAt: occurredAt,
          );
        case 'Evidence':
          // Reflection count changes alone are not surfaced as milestones.
          break;
      }
    }
  }

  return ArchiveMilestonesView(
    milestones: list,
    latest: list.isNotEmpty ? list.last : null,
  );
}

List<ArchiveMilestone> recentMilestones(
  ArchiveMilestonesView view, {
  int limit = 5,
}) {
  if (view.milestones.isEmpty) return [];
  final start = view.milestones.length > limit
      ? view.milestones.length - limit
      : 0;
  return view.milestones.sublist(start).reversed.toList();
}

String _truncate(String text, {int max = 100}) {
  final t = text.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}

String _formatPeriodLabel(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = dt.toLocal();
  return '${months[local.month - 1]} ${local.day}';
}