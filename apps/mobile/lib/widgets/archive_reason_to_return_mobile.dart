import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ArchiveReasonToReturnMobile extends StatelessWidget {
  const ArchiveReasonToReturnMobile({required this.line, super.key});

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