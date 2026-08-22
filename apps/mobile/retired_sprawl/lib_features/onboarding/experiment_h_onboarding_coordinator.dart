import 'package:archiveme_mobile/features/onboarding/experiment_h_feature_flags.dart';

/// Routes first-session onboarding through Experiment H when enabled.
abstract final class ExperimentHOnboardingCoordinator {
  ExperimentHOnboardingCoordinator._();

  static bool shouldInsertProofStep({
    required int entryCount,
    required bool isPostCapture,
  }) {
    if (!ExperimentHFeatureFlags.isEnabled) return false;
    if (!isPostCapture) return false;
    return entryCount >= 1;
  }

  static String routeFor({
    required String source,
    String? entryId,
    String continueRoute = '/record',
  }) {
    final params = <String, String>{
      'source': source,
      'continue': continueRoute,
    };
    if (entryId != null && entryId.isNotEmpty) {
      params['entryId'] = entryId;
    }
    return Uri(
      path: '/onboarding/experiment-h',
      queryParameters: params,
    ).toString();
  }
}