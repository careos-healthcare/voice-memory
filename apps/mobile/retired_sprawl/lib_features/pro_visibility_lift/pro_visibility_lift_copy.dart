import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';

abstract final class ProVisibilityLiftCopy {
  ProVisibilityLiftCopy._();

  static const String title = RevenueLiftExperimentV2Copy.proVisibilityTitle;
  static const String body = RevenueLiftExperimentV2Copy.proVisibilityBody;
  static const String primaryCta = RevenueLiftExperimentV2Copy.proVisibilityPrimaryCta;
  static const String secondaryCta =
      RevenueLiftExperimentV2Copy.proVisibilitySecondaryCta;
}

enum ProVisibilityLiftActionType { seePro, dismiss }

extension ProVisibilityLiftActionTypeStorage on ProVisibilityLiftActionType {
  String get analyticsValue => switch (this) {
    ProVisibilityLiftActionType.seePro => 'see_pro',
    ProVisibilityLiftActionType.dismiss => 'dismiss',
  };
}

enum ProVisibilityLiftSurface { recordReady, recordPostSave, archivePatterns }

extension ProVisibilityLiftSurfaceStorage on ProVisibilityLiftSurface {
  String get analyticsValue => switch (this) {
    ProVisibilityLiftSurface.recordReady => 'record_ready',
    ProVisibilityLiftSurface.recordPostSave => 'record_post_save',
    ProVisibilityLiftSurface.archivePatterns => 'archive_patterns',
  };
}