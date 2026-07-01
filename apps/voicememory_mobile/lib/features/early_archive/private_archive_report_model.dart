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
    this.previewSectionCount = 2,
  });

  final String title;
  final String intro;
  final List<PrivateArchiveReportSection> sections;
  final int previewSectionCount;

  List<PrivateArchiveReportSection> get populatedSections =>
      sections.where((section) => section.hasContent).toList();

  bool get hasContent => populatedSections.isNotEmpty;

  String plainText({required bool isPro}) =>
      isPro ? fullPlainText : previewPlainText;

  String get fullPlainText => _formatSections(populatedSections);

  String get previewPlainText {
    final preview = populatedSections.take(previewSectionCount).toList();
    final blocks = <String>[_formatSections(preview)];
    if (populatedSections.length > previewSectionCount) {
      blocks.add(PrivateArchiveReportCopy.previewProNote);
    }
    return blocks.join('\n\n');
  }

  String _formatSections(List<PrivateArchiveReportSection> items) {
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

    blocks.add(PrivateArchiveReportCopy.privateFooter);
    blocks.add(PrivateArchiveReportCopy.madeWith);

    return blocks.join('\n\n');
  }
}
