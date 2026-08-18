import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/billing/billing_service.dart';
import 'package:archiveme_mobile/data/repositories/account_repository.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/auth_service.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/services/journal_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Account-scoped dependencies for V1 critical paths (capture, archive,
/// corrections, sync, account deletion, billing).
///
/// Production screens receive this via constructor injection; tests pass fakes.
/// [fromAppServices] is the single composition-root fallback — avoid calling
/// [AppServices.instance] elsewhere on migrated paths.
class V1AccountDependencies {
  const V1AccountDependencies({
    required this.journalStore,
    required this.journal,
    required this.prefs,
    required this.pipeline,
    required this.recording,
    required this.accountRepository,
    required this.auth,
    required this.billing,
    this.liveVoiceCapture,
  });

  factory V1AccountDependencies.fromAppServices() {
    final services = AppServices.instance;
    return V1AccountDependencies(
      journalStore: services.journalStore,
      journal: services.journal,
      prefs: services.prefs,
      pipeline: services.pipeline,
      recording: services.recording,
      accountRepository: services.accountRepository,
      auth: services.auth,
      billing: services.billing,
      liveVoiceCapture: services.liveVoiceCapture,
    );
  }

  final JournalStore journalStore;
  final JournalService journal;
  final MobilePrefsStore prefs;
  final CapturePipelineService pipeline;
  final RecordingService recording;
  final AccountRepository accountRepository;
  final AuthService auth;
  final BillingService billing;
  final LiveVoiceCaptureService? liveVoiceCapture;
}