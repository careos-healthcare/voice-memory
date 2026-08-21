import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/features/capture/widgets/capture_module_bootstrap.dart';
import 'package:archiveme_mobile/features/llm/providers/llm_providers.dart';
import 'package:archiveme_mobile/features/live_audio/presentation/widgets/offline_vault_recovery_host.dart';
import 'package:archiveme_mobile/features/recording/audio_processing_queue_listener_host.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:archiveme_mobile/security/app_lock_gate.dart';
import 'package:archiveme_mobile/security/app_privacy_shell.dart';
import 'package:archiveme_mobile/security/secure_database_gate.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_app_lifecycle_listener.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ArchiveMeApp extends StatelessWidget {
  const ArchiveMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: appProviderContainer,
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
        builder: (context, child) => LocalLlmAppLifecycleListener(
          child: SecureDatabaseGate(
            child: AppLockGate(
              child: AppPrivacyShell(
                child: OfflineVaultRecoveryHost(
                  child: CaptureModuleBootstrap(
                    child: LlmAnalysisBootstrap(
                      child: AudioProcessingQueueListenerHost(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}