import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Quiet privacy / scaffold honesty — not marketing copy.
class TrustBanner extends StatelessWidget {
  const TrustBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.surface,
      child: Text(
        'Native MVP · API ${AppConfig.apiBaseUrl} · '
        'Local journal · No IAP · No push',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
      ),
    );
  }
}
