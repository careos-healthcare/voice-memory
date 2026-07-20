import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'features/live_audio/presentation/widgets/offline_vault_recovery_host.dart';
import 'router/app_router.dart';
import 'security/app_lock_gate.dart';
import 'security/app_privacy_shell.dart';
import 'theme/app_theme.dart';

class ArchiveMeApp extends StatelessWidget {
  const ArchiveMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      // App lock sits above every route: when enabled and locked, only the
      // lock screen renders — no archive content, previews, or share cards.
      builder: (context, child) => AppLockGate(
        child: AppPrivacyShell(
          child: OfflineVaultRecoveryHost(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
