import '../archive_timeline_spine/archive_timeline_spine_model.dart';

class TimelineProofMomentRow {
  const TimelineProofMomentRow({
    required this.label,
    this.detail,
  });

  final String label;
  final String? detail;
}

class TimelineProofMomentResult {
  const TimelineProofMomentResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasCorrection,
    required this.currentWeight,
    required this.rowCount,
    required this.title,
    required this.body,
    required this.rows,
    required this.currentWeightLine,
    required this.footer,
    required this.differentiationLine,
    required this.proLine,
    required this.compact,
  });

  final bool shouldShow;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasCorrection;
  final ArchiveTimelineSpineCurrentWeight currentWeight;
  final int rowCount;
  final String title;
  final String body;
  final List<TimelineProofMomentRow> rows;
  final String currentWeightLine;
  final String footer;
  final String differentiationLine;
  final String proLine;
  final bool compact;
}
