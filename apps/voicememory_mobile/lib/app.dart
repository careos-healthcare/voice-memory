import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'features/theme_system/theme_engine.dart';
import 'l10n/generated/app_localizations.dart';
import 'router/app_router.dart';
import 'security/secure_archive_shell.dart';
import 'theme/app_theme.dart';

class ArchiveMeApp extends StatelessWidget {
  const ArchiveMeApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const ProviderScope(child: _ThemedArchiveMeApp());
}

class _ThemedArchiveMeApp extends ConsumerWidget {
  const _ThemedArchiveMeApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(themeEngineProvider);
    final lightTokens = visualTokensFor(preferences, Brightness.light);
    final darkTokens = visualTokensFor(preferences, Brightness.dark);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromTokens(lightTokens),
      darkTheme: AppTheme.fromTokens(darkTokens),
      themeMode: themeModeFor(preferences.archetype),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      // Native task-switcher cover and app lock sit above every route.
      builder: (context, child) =>
          SecureArchiveShell(child: child ?? const SizedBox.shrink()),
    );
  }
}
