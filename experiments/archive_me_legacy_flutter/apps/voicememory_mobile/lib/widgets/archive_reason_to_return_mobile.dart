import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ArchiveReasonToReturnMobile extends StatelessWidget {
  const ArchiveReasonToReturnMobile({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    return Text(
      line,
      style: const TextStyle(
        fontWeight: FontWeight.w500,
        color: AppTheme.foreground,
        height: 1.45,
      ),
    );
  }
}
