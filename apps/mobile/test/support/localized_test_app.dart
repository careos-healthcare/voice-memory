import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wraps [child] with localization delegates for widget tests.
class LocalizedTestApp extends StatelessWidget {
  const LocalizedTestApp({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}

/// Wraps a router-based test app with localization delegates.
MaterialApp localizedMaterialAppRouter({required GoRouter routerConfig}) {
  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: routerConfig,
  );
}