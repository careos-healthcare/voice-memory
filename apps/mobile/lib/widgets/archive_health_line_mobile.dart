import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ArchiveHealthLineMobile extends StatelessWidget {
  const ArchiveHealthLineMobile({required this.health, super.key});

  final ArchiveHealthV3 health;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Archive Health · ${healthLabel(health)}',
      style: const TextStyle(fontSize: 12, color: AppTheme.muted),
    );
  }
}