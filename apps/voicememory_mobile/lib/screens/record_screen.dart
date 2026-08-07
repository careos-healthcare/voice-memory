import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/v1_feature_flags.dart';
import '../features/recording/recording_dependencies.dart';
import '../core/di/v1_account_dependencies.dart';
import '../features/recording/v1/recording_session_controller.dart';
import '../features/recording/v1/microphone_permission_controller.dart';
import '../features/recording/v1/capture_processing_controller.dart';
import '../features/recording/v1/post_save_result_controller.dart';
import '../features/recording/v1/recording_recovery_controller.dart';
import '../features/recording/v1/record_screen_view_model.dart';
import '../features/recording/v1/record_view_state.dart';
import '../features/weekly_review/weekly_archive_review_engine.dart'
    as weekly_review_surface;
import '../widgets/weekly_review/weekly_archive_review_card.dart'
    as weekly_review_surface;

export '../features/voice_capture/record_microphone_permission_ui.dart'
    show RecordUiState;

part '../features/recording/recording_state_controller.dart';
part '../features/recording/recording_audio_visualizer.dart';
part '../features/recording/recording_transcription_view.dart';

/// Warm light record surface — background token applied in recording_state_controller.
const Color recordScreenBackground = AppColors.backgroundPrimary;

void _recordLog(String message) {
  debugPrint('RECORD: $message');
}

void _recordPermissionUiLog(String message) {
  debugPrint('${RecordMicrophonePermissionUi.logPrefix} $message');
}

void _recordCtaLog(String message) {
  debugPrint('${RecordMicrophonePermissionUi.recordCtaLogPrefix} $message');
}

class RecordScreen extends ConsumerStatefulWidget {
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
    this.liveVoiceCapture,
    this.microphonePermissionGateway,
    this.onboardingMicStateStore,
    this.openAppSettings,
    this.navigationActivityController,
    this.accountDependencies,
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

  /// Injectable live voice service; defaults from [AppServices] when enabled.
  final LiveVoiceCaptureService? liveVoiceCapture;

  /// Injectable permission boundary for lifecycle checks and tests.
  final MicrophonePermissionGateway? microphonePermissionGateway;

  /// Injectable secure local funnel store.
  final OnboardingMicStateStore? onboardingMicStateStore;

  /// Injectable settings launcher; defaults to permission_handler.
  final Future<bool> Function()? openAppSettings;

  /// Shared with the primary shell to prevent hidden active capture.
  final RecordNavigationActivityController? navigationActivityController;

  /// Account-scoped services for capture/save; defaults from [AppServices].
  final V1AccountDependencies? accountDependencies;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}
