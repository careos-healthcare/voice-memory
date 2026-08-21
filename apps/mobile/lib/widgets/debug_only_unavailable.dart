import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Shown when a verification route is opened without the developer gate.
class DebugOnlyUnavailableScreen extends StatelessWidget {
  const DebugOnlyUnavailableScreen({
    required this.title, super.key,
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