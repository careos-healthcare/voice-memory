import '../features/recording/recording_dependencies.dart';
import '../router/route_catalog.dart';

export '../features/voice_capture/record_microphone_permission_ui.dart'
    show RecordUiState;

part '../features/recording/recording_state_controller.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({
    super.key,
    this.initialPrompt,
    this.autostartWithPrompt = false,
    @Deprecated('Removed from the V1 Record surface')
    Object? pressureCheckInStore,
    @Deprecated('Removed from the V1 Record surface')
    Object? suggestionAttributionStore,
    @Deprecated('Use AccessPolicyEngine at the generation boundary')
    Object? entitlementReader,
    @Deprecated('Purchase intent is owned by MonetizationServices')
    Object? purchaseIntentStore,
    @Deprecated('Referral capture is not part of commercial V1')
    Object? inviteAttributionStore,
    @Deprecated('Paywalls are owned by the subscription route')
    Object? paywallPresenter,
    @Deprecated('Use the canonical subscription repository')
    Object? subscriptionService,
    @Deprecated('Live voice is not part of commercial V1')
    Object? liveVoiceCapture,
    this.microphonePermissionGateway,
    this.onboardingMicStateStore,
    this.openAppSettings,
    @Deprecated('Media ingestion is not part of commercial V1')
    Object? encryptedImageEngine,
    @Deprecated('Media ingestion is not part of commercial V1')
    Object? mediaPicker,
    this.navigationActivityController,
    this.initialSavedResult,
  });

  /// Optional conversation starter from deep links / empty-state chips.
  final String? initialPrompt;

  /// When true (and mic is ready), begins recording after applying [initialPrompt].
  final bool autostartWithPrompt;

  /// Injectable permission boundary for lifecycle checks and tests.
  final MicrophonePermissionGateway? microphonePermissionGateway;

  /// Injectable secure local funnel store.
  final OnboardingMicStateStore? onboardingMicStateStore;

  /// Injectable settings launcher; defaults to permission_handler.
  final Future<bool> Function()? openAppSettings;

  /// Shared with the primary shell to prevent hidden active capture.
  final RecordNavigationActivityController? navigationActivityController;
  final CapturePipelineResult? initialSavedResult;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}
