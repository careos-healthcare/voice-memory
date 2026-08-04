import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../theme/app_spacing.dart';

class ArchiveIntelligenceSectionShell extends StatelessWidget {
  const ArchiveIntelligenceSectionShell({
    super.key,
    required this.title,
    required this.semanticIndex,
    required this.child,
  });

  final String title;
  final int semanticIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      sortKey: OrdinalSortKey(semanticIndex.toDouble()),
      label: title,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
