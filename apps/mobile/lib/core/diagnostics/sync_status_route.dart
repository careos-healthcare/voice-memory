import 'package:archiveme_mobile/core/diagnostics/system_diagnostics_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';

/// Opens system health for the current local database.
class SyncStatusRoute extends StatelessWidget {
  const SyncStatusRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return SystemDiagnosticsScreen(
      database: AppServices.isInitialized
          ? AppServices.instance.sqliteDatabase.database
          : null,
    );
  }
}
