import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Consumer-facing Pro feature identifiers for ArchiveMe billing.
enum ArchiveFeature {
  recordMoment,
  firstPattern,
  tomorrowCheck,
  returnComparison,
  usefulTakeaway,
  routineAnchor,
  lastSevenKeyMoments,
  whatArchiveMeRemembers,
  patternMap,
  archiveTimeline,
  keyMomentsSearch,
  monthlyReview,
  tier2WeeklyReview,
  tier2HistoricalComparison,
  privateRecapExport,
  fullHistory,
}

/// Free vs Pro feature map — monetizes long-term memory, not AI replies.
abstract class ArchiveProFeatureMap {
  ArchiveProFeatureMap._();

  static const int freeKeyMomentsLimit = 7;

  static const Set<ArchiveFeature> freeFeatures = {
    ArchiveFeature.recordMoment,
    ArchiveFeature.firstPattern,
    ArchiveFeature.tomorrowCheck,
    ArchiveFeature.returnComparison,
    ArchiveFeature.usefulTakeaway,
    ArchiveFeature.routineAnchor,
    ArchiveFeature.lastSevenKeyMoments,
  };

  static const Set<ArchiveFeature> proFeatures = {
    ArchiveFeature.whatArchiveMeRemembers,
    ArchiveFeature.patternMap,
    ArchiveFeature.archiveTimeline,
    ArchiveFeature.keyMomentsSearch,
    ArchiveFeature.monthlyReview,
    ArchiveFeature.tier2WeeklyReview,
    ArchiveFeature.tier2HistoricalComparison,
    ArchiveFeature.privateRecapExport,
    ArchiveFeature.fullHistory,
  };

  static bool isFree(ArchiveFeature feature) => freeFeatures.contains(feature);

  static bool isPro(ArchiveFeature feature) => proFeatures.contains(feature);

  static String featureLabel(ArchiveFeature feature) => switch (feature) {
    ArchiveFeature.recordMoment => 'Record a moment',
    ArchiveFeature.firstPattern => 'First pattern',
    ArchiveFeature.tomorrowCheck => 'Tomorrow check',
    ArchiveFeature.returnComparison => 'Return comparison',
    ArchiveFeature.usefulTakeaway => 'Useful takeaway',
    ArchiveFeature.routineAnchor => 'Routine anchor',
    ArchiveFeature.lastSevenKeyMoments => 'Last 7 key moments',
    ArchiveFeature.whatArchiveMeRemembers => 'What ArchiveMe remembers',
    ArchiveFeature.patternMap => 'Pattern map',
    ArchiveFeature.archiveTimeline => 'Archive timeline',
    ArchiveFeature.keyMomentsSearch => 'Key moments search',
    ArchiveFeature.monthlyReview => 'Monthly review',
    ArchiveFeature.tier2WeeklyReview => 'Weekly archive review',
    ArchiveFeature.tier2HistoricalComparison => 'Historical comparison',
    ArchiveFeature.privateRecapExport => 'Private recap export',
    ArchiveFeature.fullHistory => 'Full pattern history',
  };

  static String featureBenefit(ArchiveFeature feature) => switch (feature) {
    ArchiveFeature.lastSevenKeyMoments =>
      ConsumerUiCopy.freeKeepsSevenKeyMoments,
    ArchiveFeature.whatArchiveMeRemembers =>
      'See what keeps repeating across weeks and months.',
    ArchiveFeature.patternMap =>
      'Map one pattern: what shows up, what helps, what to check next.',
    ArchiveFeature.archiveTimeline =>
      'Follow how a pattern changed day by day.',
    ArchiveFeature.keyMomentsSearch => 'Search and revisit every key moment.',
    ArchiveFeature.monthlyReview =>
      'See what repeated and what changed this month.',
    ArchiveFeature.tier2WeeklyReview =>
      'See what repeated and what changed this week.',
    ArchiveFeature.tier2HistoricalComparison =>
      'Compare then vs now across your saved moments.',
    ArchiveFeature.privateRecapExport =>
      'Keep a private copy of your pattern memory.',
    ArchiveFeature.fullHistory => ConsumerUiCopy.proKeepsFullMemory,
    _ => ConsumerUiCopy.paywallSubhead,
  };

  /// Alias for [featureLabel].
  static String proFeatureLabel(ArchiveFeature feature) =>
      featureLabel(feature);

  /// Alias for [featureBenefit].
  static String proFeatureBenefit(ArchiveFeature feature) =>
      featureBenefit(feature);
}