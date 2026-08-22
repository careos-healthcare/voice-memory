/// Section types in the archive clean view.
enum ArchiveCleanSectionType {
  today,
  thisWeek,
  thisPattern,
  reviewPeriod,
  olderMoments,
  askArchive,
  cleanUpArchive,
}

/// One navigable row in the archive clean view.
class ArchiveCleanSection {
  const ArchiveCleanSection({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.primaryCtaLabel,
    required this.route,
    this.count,
    this.isAvailable = true,
  });

  final ArchiveCleanSectionType type;
  final String title;
  final String subtitle;
  final String primaryCtaLabel;
  final String route;

  /// Optional, conservative count — only set when grounded in saved data.
  final int? count;
  final bool isAvailable;
}