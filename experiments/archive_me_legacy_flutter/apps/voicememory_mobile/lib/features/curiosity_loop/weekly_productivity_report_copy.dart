/// Copy for the weekly curiosity loop productivity report.
abstract final class WeeklyProductivityReportCopy {
  WeeklyProductivityReportCopy._();

  static const route = '/weekly-report';
  static const fallbackRoute = '/record';

  static const title = 'Weekly check-ins';
  static const emptyTitle = 'Your week is just getting started';
  static const emptyBody =
      'As you complete your daily moment check-ins, your weekly '
      'productivity trends will appear here.';
  static const emptyHelper =
      'One quick reaction after each snapshot is enough to build momentum.';

  static const heroEyebrow = 'Past 7 days';
  static const heroTitle = 'You showed up';
  static String heroSubtitle(int total) =>
      total == 1 ? '1 check-in this week' : '$total check-ins this week';

  static const breakdownTitle = 'How the week felt';
  static const breakdownHelper = 'Reaction mix from your daily micro-reviews.';

  static const momentumTitle = 'Current momentum';
  static const momentumHelper = 'Anchors where you reported progress.';
  static const momentumEmpty = 'Progress signals will appear as you check in.';

  static const obstaclesTitle = 'Lingering obstacles';
  static const obstaclesHelper = 'Anchors that still feel stuck.';
  static const obstaclesEmpty = 'No recurring blockers surfaced this week.';

  static const previewEmptyMessage =
      'Save one real moment to start your weekly check-in loop';

  static String previewMessage(int totalReactions) {
    if (totalReactions == 1) {
      return '⚡️ 1 check-in this week';
    }
    return '⚡️ $totalReactions check-ins this week';
  }

  static const exportSectionTitle = 'Export & Portability';
  static const exportSectionHelper =
      'Take your weekly check-in history with you.';
  static const exportMarkdownLabel = '📄 Export Markdown Digest';
  static const exportJsonLabel = '⚙️ Backup Raw JSON';
  static const markdownCopiedToast = 'Markdown digest copied!';
  static const jsonSharedToast = 'Raw JSON backup ready to share';

  static const rollingHealthTitle = 'Rolling stability index';
  static const rollingHealthHelper =
      'Weighted across your last four weeks of hook-response telemetry.';

  static String rollingHealthStatusLabel(double score) {
    if (score >= 75) return 'Stable';
    if (score >= 50) return 'Monitoring';
    return 'Needs attention';
  }
}
