import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ArchivePulseMobile extends StatelessWidget {
  const ArchivePulseMobile({required this.line, super.key});

  final String line;

  @override
  Widget build(BuildContext context) {
    return Text(
      line,
      style: const TextStyle(color: AppTheme.muted, height: 1.45),
    );
  }
}