import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../billing/purchase_intent_return_cue.dart';
import '../../core/config/v1_feature_flags.dart';
import '../../core/di/v1_account_dependencies.dart';
import '../../features/monetization/presentation/services/revenuecat_paywall_presenter.dart';
import '../../features/pressure_retention/pressure_check_in_store.dart';
import '../../features/referral/invite_attribution.dart';
import '../../features/weekly_review/weekly_archive_review_engine.dart'
    as weekly_review_surface;
import '../../widgets/weekly_review/weekly_archive_review_card.dart'
    as weekly_review_surface;
import 'recording_dependencies.dart';
import 'v1/capture_processing_controller.dart';
import 'v1/microphone_permission_controller.dart';
import 'v1/post_save_result_controller.dart';
import 'v1/record_screen_view_model.dart';
import 'v1/record_view_state.dart';
import 'v1/recording_recovery_controller.dart';
import 'v1/recording_session_controller.dart';
import 'widgets/suggestion_pro_nudge_card.dart';

export '../voice_capture/record_microphone_permission_ui.dart'
    show RecordUiState;

part 'recording_build_context.dart';
part 'record_build_context_adapter.dart';
part 'record_surface_input_builder.dart';
part 'recording_build_context_resolver.dart';
part 'recording_audio_listener.dart';
part 'recording_state_handlers.dart';
part 'recording_state_build_dispatch.dart';
part 'views/record_pre_capture_cards.dart';
part 'widgets/recording_permission_panel.dart';
part 'views/record_capture_state_section.dart';
part 'views/record_post_save_cards.dart';
part 'views/record_screen_body.dart';
part 'views/record_screen_scaffold.dart';
part 'widgets/recording_capture_actions_widget.dart';
part 'widgets/recording_controls_widget.dart';
part 'recording_state_controller.dart';
part 'recording_audio_visualizer.dart';
part 'recording_transcription_view.dart';

/// Warm light record surface — background token applied in recording_state_controller.
const Color recordScreenBackground = AppColors.backgroundPrimary;

void _recordLog(String message) {
  AppLogger.debug('RECORD: $message');
}

void _recordPermissionUiLog(String message) {
  AppLogger.debug('${RecordMicrophonePermissionUi.logPrefix} $message');
}

void _recordCtaLog(String message) {
  AppLogger.debug('${RecordMicrophonePermissionUi.recordCtaLogPrefix} $message');
}

/// Primary record tab — coordinator widget composing modular recording feature parts.
///
/// **Archived production path:** [CaptureScreenHost] owns all production capture.
/// Kept for characterization tests and dedicated legacy review — not routed in V1.
@Deprecated('Use CaptureScreenHost. Legacy controller archived from production.')
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