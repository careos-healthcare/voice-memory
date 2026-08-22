import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/pro_conversion_audit/pro_conversion_audit_copy.dart';

/// Gates when the comparison engine may surface the Pro longer-trail milestone.
abstract final class ProTrailGate {
  ProTrailGate._();

  /// Free users see one past moment in comparison evidence; Pro sees the full thread.
  static const int freeHistoricalMomentLimit = 1;

  /// Minimum saved moments before a conversion milestone may appear.
  static const int minMomentsForConversionMilestone = 2;

  static const Set<PatternState> _meaningfulPatternStates = {
    PatternState.possibleRepeat,
    PatternState.clearRepeat,
    PatternState.stillCurrent,
    PatternState.changed,
    PatternState.softened,
    PatternState.fading,
    PatternState.corrected,
  };

  /// Limits historical context included in free-tier comparison payloads.
  static List<ArchiveMomentRecord> visibleHistoricalMoments({
    required List<ArchiveMomentRecord> moments,
    required bool isPro,
  }) {
    if (isPro || moments.length <= freeHistoricalMomentLimit) {
      return List<ArchiveMomentRecord>.from(moments);
    }
    return moments.sublist(moments.length - freeHistoricalMomentLimit);
  }

  /// True when a free user has earned the post-comparison Pro trail milestone.
  static bool hasReachedConversionMilestone({
    required PatternState alignmentState,
    required int totalMomentCount,
    required bool isPro,
  }) {
    if (isPro) return false;
    if (totalMomentCount < minMomentsForConversionMilestone) return false;
    return _meaningfulPatternStates.contains(alignmentState);
  }

  /// Whether to show the Pro longer-trail prompt after a comparison result.
  static bool shouldShowProTrailPrompt({
    required bool isPro,
    required bool hasDismissedProTrailPrompt,
    required PatternState alignmentState,
    required int totalMomentCount,
  }) =>
      !isPro &&
      !hasDismissedProTrailPrompt &&
      hasReachedConversionMilestone(
        alignmentState: alignmentState,
        totalMomentCount: totalMomentCount,
        isPro: isPro,
      );

  static String get conversionHeadline =>
      ProConversionAuditCopy.proTrailCanonical;
}