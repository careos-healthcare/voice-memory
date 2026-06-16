import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown when a verification route is opened without the developer gate.
class DebugOnlyUnavailableScreen extends StatelessWidget {
  const DebugOnlyUnavailableScreen({
    super.key,
    required this.title,
    this.message =
        'This tool is only available in debug builds or after unlocking developer settings.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: AppTheme.background, title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: const TextStyle(color: AppTheme.muted, height: 1.45),
        ),
      ),
    );
  }
}
