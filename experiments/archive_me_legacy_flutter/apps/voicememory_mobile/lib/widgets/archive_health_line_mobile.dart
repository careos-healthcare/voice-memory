import 'package:flutter/material.dart';

import '../features/archive_state_object/archive_state_object.dart';
import '../theme/app_theme.dart';

class ArchiveHealthLineMobile extends StatelessWidget {
  const ArchiveHealthLineMobile({super.key, required this.health});

  final ArchiveHealthV3 health;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Archive Health · ${healthLabel(health)}',
      style: const TextStyle(fontSize: 12, color: AppTheme.muted),
    );
  }
}
