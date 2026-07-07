import 'archive_timeline_spine_copy.dart';

enum ArchiveTimelineSpineRowId {
  firstSeen,
  returned,
  stillCurrent,
  correctedByYou,
  weightChanged,
  needsFreshProof,
}

extension ArchiveTimelineSpineRowIdAnalytics on ArchiveTimelineSpineRowId {
  String get analyticsValue => switch (this) {
        ArchiveTimelineSpineRowId.firstSeen => 'first_seen',
        ArchiveTimelineSpineRowId.returned => 'returned',
        ArchiveTimelineSpineRowId.stillCurrent => 'still_current',
        ArchiveTimelineSpineRowId.correctedByYou => 'corrected_by_you',
        ArchiveTimelineSpineRowId.weightChanged => 'weight_changed',
        ArchiveTimelineSpineRowId.needsFreshProof => 'needs_fresh_proof',
      };
}

enum ArchiveTimelineSpineCurrentWeight {
  strong,
  light,
  fading,
  corrected,
  needsFreshProof,
}

extension ArchiveTimelineSpineCurrentWeightAnalytics
    on ArchiveTimelineSpineCurrentWeight {
  String get analyticsValue => switch (this) {
        ArchiveTimelineSpineCurrentWeight.strong => 'strong',
        ArchiveTimelineSpineCurrentWeight.light => 'light',
        ArchiveTimelineSpineCurrentWeight.fading => 'fading',
        ArchiveTimelineSpineCurrentWeight.corrected => 'corrected',
        ArchiveTimelineSpineCurrentWeight.needsFreshProof => 'needs_fresh_proof',
      };
}

class ArchiveTimelineSpineRow {
  const ArchiveTimelineSpineRow({
    required this.id,
    required this.label,
    required this.detail,
  });

  final ArchiveTimelineSpineRowId id;
  final String label;
  final String detail;
}

class ArchiveTimelineSpineResult {
  const ArchiveTimelineSpineResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasCorrection,
    required this.currentWeight,
    required this.rows,
    required this.title,
    required this.subtitle,
    required this.explanation,
    required this.currentWeightLabel,
    required this.footer,
    required this.differentiationLine,
    required this.proBridgeCopy,
  });

  final bool shouldShow;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasCorrection;
  final ArchiveTimelineSpineCurrentWeight currentWeight;
  final List<ArchiveTimelineSpineRow> rows;
  final String title;
  final String subtitle;
  final String explanation;
  final String currentWeightLabel;
  final String footer;
  final String differentiationLine;
  final String proBridgeCopy;

  int get rowCount => rows.length;
}
