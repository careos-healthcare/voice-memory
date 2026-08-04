import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/entry_memory_mode.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Per-entry memory mode picker — three options that narrow global scope.
class EntryMemoryScopePicker extends StatefulWidget {
  const EntryMemoryScopePicker({super.key, this.entryCount});

  final int? entryCount;

  @override
  State<EntryMemoryScopePicker> createState() => _EntryMemoryScopePickerState();
}

class _EntryMemoryScopePickerState extends State<EntryMemoryScopePicker> {
  @override
  void initState() {
    super.initState();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryMemoryScopeSeen,
      entryCount: widget.entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
      oncePerSession: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MemoryScopePolicy.scope == MemoryScope.off) {
      return Column(
        key: const Key('entry_memory_scope_off'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            EntryMemoryModeCopy.sectionTitle,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: 2),
          Text(
            EntryMemoryModeCopy.memoryOffTitle,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            EntryMemoryModeCopy.memoryOffBody,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    final selected = EntryMemoryModeSession.selectedMode;
    return Column(
      key: const Key('entry_memory_scope_picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          EntryMemoryModeCopy.sectionTitle,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final mode in EntryMemoryMode.values)
          _ModeTile(
            mode: mode,
            selected: selected == mode,
            onTap: () {
              EntryMemoryModeSession.select(
                mode,
                entryCount: widget.entryCount,
              );
              setState(() {});
            },
          ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final EntryMemoryMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('entry_memory_mode_${mode.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected
                  ? AppColors.accentPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: ArchiveMobileTypography.responsiveHelper(context)
                        .copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                  ),
                  Text(
                    mode.helper,
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
