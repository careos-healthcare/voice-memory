import 'package:archiveme_mobile/features/archive_tab/archive_tab_four_state_engine.dart';
import 'package:archiveme_mobile/widgets/archive/archive_tab_entry_state_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Zero-entry Archive tab — one calm message and a record CTA only.
class PatternsEmptyArchivePreviewCard extends StatelessWidget {
  const PatternsEmptyArchivePreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final model = ArchiveTabFourStateEngine.build(entries: const [])!;
    return ArchiveTabEntryStateCard(
      model: model,
      onPrimary: () => context.go('/record'),
    );
  }
}