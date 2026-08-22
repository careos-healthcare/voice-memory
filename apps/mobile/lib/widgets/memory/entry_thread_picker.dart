import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/archive_thread.dart';
import 'package:archiveme_mobile/features/memory/entry_memory_mode.dart';
import 'package:archiveme_mobile/features/memory/entry_thread_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/memory/new_thread_sheet.dart';
import 'package:flutter/material.dart';

/// Thread/project picker for the entry being saved.
class EntryThreadPicker extends StatefulWidget {
  const EntryThreadPicker({required this.threads, super.key, this.entryCount});

  final List<ArchiveThread> threads;
  final int? entryCount;

  @override
  State<EntryThreadPicker> createState() => _EntryThreadPickerState();
}

class _EntryThreadPickerState extends State<EntryThreadPicker> {
  @override
  void initState() {
    super.initState();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryThreadScopeSeen,
      entryCount: widget.entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
      oncePerSession: true,
    );
  }

  bool get _disabled =>
      EntryMemoryModeSession.selectedMode == EntryMemoryMode.keepSeparate;

  @override
  Widget build(BuildContext context) {
    final scope = EntryThreadScopeSession.selectedScope;
    return Opacity(
      opacity: _disabled ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: _disabled,
        child: Column(
          key: const Key('entry_thread_picker'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              EntryThreadScopeCopy.sectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final threadScope in EntryThreadScope.values)
              _ScopeTile(
                scope: threadScope,
                selected: scope == threadScope,
                onTap: () => _selectScope(threadScope),
              ),
            if (scope == EntryThreadScope.existingThread) ...[
              const SizedBox(height: AppSpacing.xs),
              if (widget.threads.isEmpty)
                Text(
                  '${EntryThreadScopeCopy.emptyThreadsTitle}. '
                  '${EntryThreadScopeCopy.emptyThreadsBody}',
                  key: const Key('entry_thread_empty_state'),
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final thread in widget.threads)
                      ChoiceChip(
                        key: Key('entry_thread_choice_${thread.id}'),
                        label: Text(thread.name),
                        selected:
                            EntryThreadScopeSession.selectedThreadId ==
                            thread.id,
                        onSelected: (_) {
                          EntryThreadScopeSession.selectExistingThread(
                            thread.id,
                            entryCount: widget.entryCount,
                          );
                          setState(() {});
                        },
                      ),
                  ],
                ),
            ],
            if (scope == EntryThreadScope.newThread) ...[
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                key: const Key('entry_thread_new_sheet_cta'),
                onPressed: () async {
                  final name = await showNewThreadSheet(context);
                  if (name == null || !mounted) return;
                  EntryThreadScopeSession.setPendingNewThreadName(name);
                  setState(() {});
                },
                child: Text(
                  EntryThreadScopeSession.pendingNewThreadName?.isNotEmpty ==
                          true
                      ? EntryThreadScopeSession.pendingNewThreadName!
                      : EntryThreadScopeCopy.newThreadLabel,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectScope(EntryThreadScope threadScope) {
    if (threadScope == EntryThreadScope.newThread) {
      EntryThreadScopeSession.selectScope(
        threadScope,
        entryCount: widget.entryCount,
      );
      setState(() {});
      return;
    }
    EntryThreadScopeSession.selectScope(
      threadScope,
      entryCount: widget.entryCount,
    );
    setState(() {});
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.scope,
    required this.selected,
    required this.onTap,
  });

  final EntryThreadScope scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('entry_thread_scope_${scope.id}'),
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
                    scope.label,
                    style: ArchiveMobileTypography.responsiveHelper(context)
                        .copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                  ),
                  Text(
                    scope.helper,
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