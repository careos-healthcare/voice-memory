/// V1 critical-path sources that must not access [AppServices.instance]
/// directly. Composition roots ([V1AccountDependencies.fromAppServices],
/// [AppServicesPaywallDependencies]) are exempt.
abstract final class V1CriticalPathFiles {
  V1CriticalPathFiles._();

  static const noServiceLocatorAccess = [
    'lib/features/recording/recording_state_controller.dart',
    'lib/features/recording/recording_transcription_view.dart',
    'lib/services/capture_pipeline_service.dart',
    'lib/screens/delete_account_screen.dart',
    'lib/screens/archive_belief_screen.dart',
    'lib/screens/entry_detail_screen.dart',
    'lib/screens/quick_text_capture_screen.dart',
  ];
}
