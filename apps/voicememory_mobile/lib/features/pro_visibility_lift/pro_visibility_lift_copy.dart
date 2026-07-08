import '../revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';

abstract final class ProVisibilityLiftCopy {
  ProVisibilityLiftCopy._();

  static const title = RevenueLiftExperimentV2Copy.proVisibilityTitle;
  static const body = RevenueLiftExperimentV2Copy.proVisibilityBody;
  static const primaryCta = RevenueLiftExperimentV2Copy.proVisibilityPrimaryCta;
  static const secondaryCta = RevenueLiftExperimentV2Copy.proVisibilitySecondaryCta;
}

enum ProVisibilityLiftActionType {
  seePro,
  dismiss,
}

extension ProVisibilityLiftActionTypeStorage on ProVisibilityLiftActionType {
  String get analyticsValue => switch (this) {
        ProVisibilityLiftActionType.seePro => 'see_pro',
        ProVisibilityLiftActionType.dismiss => 'dismiss',
      };
}

enum ProVisibilityLiftSurface {
  recordReady,
  recordPostSave,
  archivePatterns,
}

extension ProVisibilityLiftSurfaceStorage on ProVisibilityLiftSurface {
  String get analyticsValue => switch (this) {
        ProVisibilityLiftSurface.recordReady => 'record_ready',
        ProVisibilityLiftSurface.recordPostSave => 'record_post_save',
        ProVisibilityLiftSurface.archivePatterns => 'archive_patterns',
      };
}
