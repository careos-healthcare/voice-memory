import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ArchivePulseMobile extends StatelessWidget {
  const ArchivePulseMobile({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    return Text(
      line,
      style: const TextStyle(color: AppTheme.muted, height: 1.45),
    );
  }
}
