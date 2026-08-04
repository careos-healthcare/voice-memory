import '../../design/user_facing_date.dart';
import 'monthly_ambition_pressure_review_model.dart';
import 'prove_enough_evidence_trail_model.dart';
import 'prove_enough_pattern_report_model.dart';

/// Builds a Markdown prove_enough pattern report from saved excerpts only.
class ProveEnoughPatternReportExporter {
  const ProveEnoughPatternReportExporter();

  String toMarkdown(ProveEnoughPatternReport report) {
    final monthly = report.monthlyReview;
    final buffer = StringBuffer()
      ..writeln('# ${ProveEnoughPatternReport.reportTitle}')
      ..writeln()
      ..writeln('**Generated:** ${formatUserFacingDate(report.generatedAt)}')
      ..writeln('**From:** ArchiveMe');

    final rangeLine = _dateRangeLine(report);
    if (rangeLine != null) {
      buffer.writeln('**Date range:** $rangeLine');
    }
    buffer.writeln();

    buffer
      ..writeln('## ${ProveEnoughPatternReport.summarySection}')
      ..writeln()
      ..writeln(_summaryBody(report))
      ..writeln()
      ..writeln('## ${ProveEnoughPatternReport.evidenceTrailSection}')
      ..writeln()
      ..writeln(_evidenceTrailBody(report))
      ..writeln()
      ..writeln('## ${ProveEnoughPatternReport.choiceVsPressureSection}')
      ..writeln()
      ..writeln(_choiceVsPressureBody(report))
      ..writeln()
      ..writeln('## ${ProveEnoughPatternReport.restGuiltSection}')
      ..writeln()
      ..writeln(_restGuiltBody(report))
      ..writeln()
      ..writeln('## ${ProveEnoughPatternReport.triggerMapSection}')
      ..writeln()
      ..writeln(_triggerMapBody(report))
      ..writeln()
      ..writeln('## ${ProveEnoughPatternReport.confirmedSection}')
      ..writeln()
      ..writeln(_momentsBody(report.trail.supportingMoments))
      ..writeln()
      ..writeln('## ${ProveEnoughPatternReport.challengedSection}')
      ..writeln()
      ..writeln(_momentsBody(report.trail.contradictionMoments))
      ..writeln()
      ..writeln('## ${ProveEnoughPatternReport.directionSection}')
      ..writeln()
      ..writeln(_directionBody(monthly))
      ..writeln()
      ..writeln('## ${ProveEnoughPatternReport.nextMissionSection}')
      ..writeln()
      ..writeln(_nextMissionBody(report));

    return buffer.toString().trim();
  }

  String? _dateRangeLine(ProveEnoughPatternReport report) {
    final start = report.rangeStart;
    final end = report.rangeEnd;
    if (start == null || end == null) return null;
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return formatUserFacingDate(start);
    }
    return '${formatUserFacingDate(start)} – ${formatUserFacingDate(end)}';
  }

  String _summaryBody(ProveEnoughPatternReport report) {
    final monthly = report.monthlyReview;
    final lines = <String>[
      '- Confirming moments saved: ${report.trail.supportingMoments.length}',
      '- Challenging moments saved: ${report.trail.contradictionMoments.length}',
      '- Rest guilt moments saved: ${report.trail.restGuiltMoments.length}',
      '- Choice moments saved: ${report.trail.choiceMoments.length}',
    ];

    if (monthly != null && monthly.hasEnoughData) {
      lines.add(
        '- ${monthly.monthLabel} proving moments tracked: ${monthly.totalProvingMoments}',
      );
      lines.add('- Loop direction: ${monthly.direction.copy}');
    } else if (report.trail.whatChanged.trim().isNotEmpty) {
      lines.add('- What changed: ${report.trail.whatChanged.trim()}');
    }

    return lines.join('\n');
  }

  String _evidenceTrailBody(ProveEnoughPatternReport report) {
    final moments = report.allMoments;
    if (moments.isEmpty) {
      return '_No saved excerpts yet._';
    }
    return _momentsBody(moments);
  }

  String _choiceVsPressureBody(ProveEnoughPatternReport report) {
    final monthly = report.monthlyReview;
    final lines = <String>[];

    if (monthly != null && monthly.choiceVsPressureSummary.trim().isNotEmpty) {
      lines.add(monthly.choiceVsPressureSummary.trim());
    } else {
      lines.add(
        'Pressure-related moments: ${report.trail.supportingMoments.length}',
      );
      lines.add('Choice-related moments: ${report.trail.choiceMoments.length}');
    }

    if (report.trail.choiceMoments.isNotEmpty) {
      lines.add('');
      lines.add(_momentsBody(report.trail.choiceMoments));
    }

    return lines.join('\n').trim();
  }

  String _restGuiltBody(ProveEnoughPatternReport report) {
    final monthly = report.monthlyReview;
    if (monthly != null && monthly.restGuiltSummary.trim().isNotEmpty) {
      return monthly.restGuiltSummary.trim();
    }
    return _momentsBody(report.trail.restGuiltMoments);
  }

  String _triggerMapBody(ProveEnoughPatternReport report) {
    final monthly = report.monthlyReview;
    if (monthly != null && monthly.triggerMapSummary.trim().isNotEmpty) {
      return monthly.triggerMapSummary.trim();
    }
    final summary = report.trail.triggerSummary.trim();
    if (summary.isNotEmpty) return summary;
    return '_No clear trigger pattern saved yet._';
  }

  String _directionBody(MonthlyAmbitionPressureReview? monthly) {
    if (monthly == null || !monthly.hasEnoughData) {
      return '_ArchiveMe needs more moments before calling a direction._';
    }

    final lines = <String>[monthly.direction.copy];
    if (monthly.whatChanged.trim().isNotEmpty) {
      lines.add(monthly.whatChanged.trim());
    }
    for (final line in monthly.directionEvidence) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) lines.add('- $trimmed');
    }
    return lines.join('\n');
  }

  String _nextMissionBody(ProveEnoughPatternReport report) {
    final mission = report.nextEvidenceMission;
    if (mission.isEmpty) {
      return '_No next evidence mission saved yet._';
    }
    return mission;
  }

  String _momentsBody(List<ProveEnoughEvidenceMoment> moments) {
    if (moments.isEmpty) return '_No saved excerpts yet._';
    return moments
        .map(
          (moment) =>
              '- ${formatUserFacingDate(moment.createdAt)}: "${moment.excerpt}"',
        )
        .join('\n');
  }
}
