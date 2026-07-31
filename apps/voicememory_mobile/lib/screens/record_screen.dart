import '../features/recording/recording_dependencies.dart';
import '../features/weekly_review/weekly_archive_review_engine.dart'
    as weekly_review_surface;
import '../widgets/weekly_review/weekly_archive_review_card.dart'
    as weekly_review_surface;

export '../features/voice_capture/record_microphone_permission_ui.dart'
    show RecordUiState;

part '../features/recording/recording_state_controller.dart';
part '../features/recording/recording_audio_visualizer.dart';
part '../features/recording/recording_transcription_view.dart';
part '../features/recording/recording_metadata_sheet.dart';

void _recordLog(String message) {
  debugPrint('RECORD: $message');
}

void _recordPermissionUiLog(String message) {
  debugPrint('${RecordMicrophonePermissionUi.logPrefix} $message');
}

void _recordCtaLog(String message) {
  debugPrint('${RecordMicrophonePermissionUi.recordCtaLogPrefix} $message');
}

final class _RecordScreenLogger {
  const _RecordScreenLogger();

  void info(String message) {
    RecordPipelineLog.log(message);
  }
}

class RecordScreen extends StatefulWidget {
  const RecordScreen({
    super.key,
    this.initialPrompt,
    this.autostartWithPrompt = false,
    this.pressureCheckInStore,
    this.suggestionAttributionStore,
    this.entitlementReader,
    this.purchaseIntentStore,
    this.inviteAttributionStore,
    this.paywallPresenter,
    this.subscriptionService,
    this.liveVoiceCapture,
    this.microphonePermissionGateway,
    this.onboardingMicStateStore,
    this.openAppSettings,
    this.encryptedImageEngine,
    this.mediaPicker,
    this.navigationActivityController,
  });

  /// Optional conversation starter from deep links / empty-state chips.
  final String? initialPrompt;

  /// When true (and mic is ready), begins recording after applying [initialPrompt].
  final bool autostartWithPrompt;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PressureCheckInStore? pressureCheckInStore;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final SuggestionAttributionStore? suggestionAttributionStore;

  /// Injectable for tests; defaults to the live billing-backed reader.
  final ArchiveEntitlementReader? entitlementReader;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final PurchaseIntentStore? purchaseIntentStore;

  /// Injectable for tests; defaults to the live prefs-backed store.
  final InviteAttributionStore? inviteAttributionStore;

  /// Injectable for tests; defaults to the live RevenueCat UI presenter.
  final RevenueCatPaywallPresenter? paywallPresenter;
  final SubscriptionService? subscriptionService;

  /// Injectable live voice service; defaults from [AppServices] when enabled.
  final LiveVoiceCaptureService? liveVoiceCapture;

  /// Injectable permission boundary for lifecycle checks and tests.
  final MicrophonePermissionGateway? microphonePermissionGateway;

  /// Injectable secure local funnel store.
  final OnboardingMicStateStore? onboardingMicStateStore;

  /// Injectable settings launcher; defaults to permission_handler.
  final Future<bool> Function()? openAppSettings;

  /// Injectable encrypted media boundaries; production falls back to AppServices.
  final EncryptedImageEngine? encryptedImageEngine;
  final MediaPickerGateway? mediaPicker;

  /// Shared with the primary shell to prevent hidden active capture.
  final RecordNavigationActivityController? navigationActivityController;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}
