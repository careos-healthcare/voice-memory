abstract final class ProVisibilityLiftCopy {
  ProVisibilityLiftCopy._();

  static const title = 'This is the paid moment';
  static const body =
      'Your first proof is free. Pro keeps the longer timeline behind it.';
  static const primaryCta = 'See what Pro keeps';
  static const secondaryCta = 'Not now';
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
