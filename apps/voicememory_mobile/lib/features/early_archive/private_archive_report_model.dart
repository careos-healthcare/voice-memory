import '../private_report/private_report_copy.dart';
import 'private_archive_report_copy.dart';

/// One section of the private archive report.
class PrivateArchiveReportSection {
  const PrivateArchiveReportSection({
    required this.heading,
    this.lines = const [],
    this.bullets = const [],
  });

  final String heading;
  final List<String> lines;
  final List<String> bullets;

  bool get hasEvidence =>
      lines.any(
        (line) =>
            line.trim().isNotEmpty &&
            line.trim() != PrivateReportCopy.notEnoughEvidence,
      ) ||
      bullets.any((bullet) => bullet.trim().isNotEmpty);

  bool get hasContent =>
      lines.any((line) => line.trim().isNotEmpty) ||
      bullets.any((bullet) => bullet.trim().isNotEmpty);
}

/// Private archive report built from proof engines — summaries only.
class PrivateArchiveReport {
  const PrivateArchiveReport({
    required this.title,
    required this.intro,
    required this.sections,
    this.previewSectionCount = 1,
  });

  final String title;
  final String intro;
  final List<PrivateArchiveReportSection> sections;
  final int previewSectionCount;

  List<PrivateArchiveReportSection> get populatedSections =>
      sections.where((section) => section.hasContent).toList();

  bool get hasContent => sections.any((section) => section.hasEvidence);

  String plainText({required bool isPro}) =>
      isPro ? fullPlainText : previewPlainText;

  String get fullPlainText => _formatReport(sections, includeScope: true);

  String get previewPlainText {
    final previewSections = sections.take(previewSectionCount).toList();
    final blocks = <String>[
      PrivateArchiveReportCopy.previewTitle,
      PrivateArchiveReportCopy.previewBody,
      _formatReport(previewSections, includeScope: true),
    ];
    return blocks.join('\n\n');
  }

  String visiblePlainText({
    required bool isPro,
    int previewSectionCount = 1,
  }) {
    final visibleSections = <PrivateArchiveReportSection>[];
    for (var i = 0; i < sections.length; i++) {
      if (isPro || i < previewSectionCount) {
        visibleSections.add(sections[i]);
      }
    }
    return _formatReport(visibleSections, includeScope: true);
  }

  String _formatReport(
    List<PrivateArchiveReportSection> items, {
    required bool includeScope,
  }) {
    final blocks = <String>[title.trim(), intro.trim()];

    for (final section in items) {
      final sectionBlocks = <String>[section.heading.trim()];

      for (final line in section.lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) sectionBlocks.add(trimmed);
      }

      for (final bullet in section.bullets) {
        final trimmed = bullet.trim();
        if (trimmed.isNotEmpty) sectionBlocks.add('- $trimmed');
      }

      blocks.add(sectionBlocks.join('\n'));
    }

    if (includeScope) {
      blocks.add(_formatScopeList(
        PrivateArchiveReportCopy.exportIncludedHeading,
        PrivateArchiveReportCopy.exportIncludedItems,
      ));
      blocks.add(_formatScopeList(
        PrivateArchiveReportCopy.exportNotIncludedHeading,
        PrivateArchiveReportCopy.exportNotIncludedItems,
      ));
    }

    return blocks.join('\n\n');
  }

  String _formatScopeList(String heading, List<String> items) {
    final lines = <String>[heading.trim()];
    for (final item in items) {
      lines.add('- $item');
    }
    return lines.join('\n');
  }
}
