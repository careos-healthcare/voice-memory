import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/archive_mobile_page_template.dart';

/// Secondary archive tools — demoted from primary nav.
class ArchiveDetailScreen extends StatelessWidget {
  const ArchiveDetailScreen({super.key});

  static const _links = [
    ('/archive-belief', 'Belief dossier'),
    ('/archive-belief', 'Evidence locker'),
    ('/blind-spots', 'Pattern review'),
    ('/memory', 'Reflection log'),
    ('/search', 'Search'),
    ('/theories', 'Archive beliefs'),
    ('/updates', 'Changes feed'),
    ('/journal', 'Reflection log (journal)'),
    ('/export', 'Export'),
  ];

  @override
  Widget build(BuildContext context) {
    return ArchiveMobilePageTemplate(
      eyebrow: 'Archive detail',
      title: 'Archive detail',
      lead:
          'Secondary tools — belief and changes stay on Archive and Changes tabs.',
      mainContent: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (path, label) in _links)
            OutlinedButton(
              onPressed: () => context.push(path),
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
      actionArea: TextButton(
        onPressed: () => context.go('/archive-belief'),
        child: const Text(
          'Back to Archive',
          style: TextStyle(color: AppTheme.muted),
        ),
      ),
    );
  }
}
