import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

class PlaceholderPanel extends StatelessWidget {
  const PlaceholderPanel({
    required this.title, required this.body, super.key,
    this.status,
  });

  final String title;
  final String body;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(color: AppTheme.muted)),
            if (status != null) ...[
              const SizedBox(height: 12),
              Text(status!, style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}