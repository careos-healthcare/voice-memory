import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../product/core_product_vision.dart';
import '../router/onboarding_gate.dart';
import '../security/private_storage_audit.dart';
import '../services/app_services.dart';
import '../services/privacy/sensitive_temporary_audio_store.dart';
import '../storage/app_storage_paths.dart';
import '../theme/app_colors.dart';

/// Completes startup work that touches local storage and platform services.
Future<void> completeArchiveMeStartup() async {
  await AppStoragePaths.configureFromDeviceInfo();
  await SensitiveTemporaryAudioStore.production.purge();
  await AppServices.initialize();
  await SensitiveTemporaryAudioStore.production.migrateLegacyOnce(
    knownOwnerId: 'archive:${AppServices.instance.journalStore.ownerArchiveId}',
  );
  await SensitiveTemporaryAudioStore.production.purge();
  await AppServices.instance.transcriptionWorkScheduler.initialize();
  if (AppServices.instance.transcriptionLedger.jobs.any(
    (job) => !job.isTerminal,
  )) {
    unawaited(AppServices.instance.transcriptionWorkScheduler.schedule());
  }
  PrivateStorageAudit.logAuditReport();
  await onboardingGate.refresh();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  scheduleDeferredArchiveMeStartup();
}

/// Starts the analytics provider, monetization, sync and the derived archive
/// stores after the first frame.
///
/// Capture must never wait on any of them, so they are deliberately not part of
/// [completeArchiveMeStartup]. They still run on every launch.
void scheduleDeferredArchiveMeStartup() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AppServices.activateDeferredServices());
  });
}

/// Shows the first frame immediately, then runs [completeArchiveMeStartup].
class ArchiveMeBootstrapApp extends StatefulWidget {
  const ArchiveMeBootstrapApp({super.key});

  @override
  State<ArchiveMeBootstrapApp> createState() => _ArchiveMeBootstrapAppState();
}

class _ArchiveMeBootstrapAppState extends State<ArchiveMeBootstrapApp>
    with WidgetsBindingObserver {
  bool _ready = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAfterFirstFrame());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(SensitiveTemporaryAudioStore.production.handleLifecycle(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initAfterFirstFrame() async {
    try {
      await completeArchiveMeStartup();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ARCHIVEME_SIMULATOR_NATIVE_ASSETS: startup failed: $e');
        debugPrint('$st');
      }
      _startupError = e;
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && _startupError == null) {
      return const ArchiveMeApp();
    }
    if (_ready && _startupError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'ArchiveMe could not start local storage on this simulator.\n'
                '$_startupError',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ArchiveMeStartupSplash(),
    );
  }
}

class ArchiveMeStartupSplash extends StatelessWidget {
  const ArchiveMeStartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: 'ArchiveMe. ${CoreProductVision.valueProposition} Loading.',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ArchiveMe',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    CoreProductVision.valueProposition,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
