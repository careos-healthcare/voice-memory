import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/billing/purchase_intent_return_cue.dart';
import 'package:archiveme_mobile/billing/value_moment_paywall_trigger.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/pressure_retention/daily_return_suggestion_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_model.dart';
import 'package:archiveme_mobile/features/record/record_stack_policy.dart';
import 'package:archiveme_mobile/features/recording/record_surface_flags.dart';
import 'package:archiveme_mobile/features/recording/record_surface_resolver.dart' show RecordSurfaceResolver;
import 'package:archiveme_mobile/features/recording/record_user_pro_state.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_model.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Immutable inputs for [RecordSurfaceResolver.resolve].
final class RecordSurfaceInput {
  const RecordSurfaceInput({
    required this.ui,
    required this.flags,
    required this.journalEntries,
    required this.entryCount,
    required this.entryCountLoaded,
    required this.isPostSave,
    required this.userProState,
    required this.micPhase,
    required this.micPermissionState,
    required this.micUserDeniedThisSession,
    required this.sessionRequiresOpenSettings,
    required this.compactLayout,
    required this.stackDecision,
    required this.error,
    required this.localSaveTitle,
    required this.syncNoteRaw,
    required this.stageLabelRaw,
    required this.entriesAfterSave,
    required this.lastCaptureAnalysisSucceeded,
    required this.showPostSaveLoop,
    required this.lastSavedEntry,
    required this.lastSavedEntryIsDegraded,
    required this.recordReturnProJustSaved,
    required this.recordReturnCueVisible,
    required this.savedFromConfirmedRepeatTrigger,
    required this.savedFromHelpfulAction,
    required this.earlyEvidenceTriggerCaptured,
    required this.earlyEvidenceHelpfulCaptured,
    required this.earlyReturnReminderOffer,
    required this.earlyReturnReminderHidden,
    required this.secondSessionComparison,
    required this.valueMomentBridge,
    required this.purchaseIntentCue,
    required this.betaActivationLoopCounts,
    required this.betaFeedbackCaptured,
    required this.canShowArchiveProgressCards,
    required this.dailyReturnSuggestions,
    required this.hasWatchTheme,
    required this.offerDayTwoReminder,
    required this.postSaveCuriosityHook,
    required this.shareableProof,
    required this.applyEmptyArchiveGates,
    this.visualAuditPresentationKey = 0,
  });

  final RecordUiState ui;
  final RecordSurfaceFlags flags;
  final List<JournalEntry> journalEntries;
  final int entryCount;
  final bool entryCountLoaded;
  final bool isPostSave;
  final RecordUserProState userProState;
  final RecordingPhase micPhase;
  final MicrophonePermissionState micPermissionState;
  final bool micUserDeniedThisSession;
  final bool sessionRequiresOpenSettings;
  final bool compactLayout;
  final RecordStackDecision stackDecision;
  final String? error;
  final String? localSaveTitle;
  final String? syncNoteRaw;
  final String stageLabelRaw;
  final List<JournalEntry> entriesAfterSave;
  final bool lastCaptureAnalysisSucceeded;
  final bool showPostSaveLoop;
  final JournalEntry? lastSavedEntry;
  final bool lastSavedEntryIsDegraded;
  final bool recordReturnProJustSaved;
  final bool recordReturnCueVisible;
  final bool savedFromConfirmedRepeatTrigger;
  final bool savedFromHelpfulAction;
  final bool earlyEvidenceTriggerCaptured;
  final bool earlyEvidenceHelpfulCaptured;
  final bool earlyReturnReminderOffer;
  final bool earlyReturnReminderHidden;
  final SecondSessionComparison? secondSessionComparison;
  final ValueMomentBridge? valueMomentBridge;
  final PendingPurchaseIntent? purchaseIntentCue;
  final BetaActivationLoopCounts betaActivationLoopCounts;
  final bool betaFeedbackCaptured;
  final bool canShowArchiveProgressCards;
  final DailyReturnSuggestionSet dailyReturnSuggestions;
  final bool hasWatchTheme;
  final bool offerDayTwoReminder;
  final CuriosityHook? postSaveCuriosityHook;
  final ShareableArchiveProof? shareableProof;
  final bool applyEmptyArchiveGates;
  final int visualAuditPresentationKey;
}