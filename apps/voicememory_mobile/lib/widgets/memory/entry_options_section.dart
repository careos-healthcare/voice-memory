import 'package:flutter/material.dart';

import '../../features/archive_packs/archive_pack.dart';
import '../../features/archive_packs/archive_pack_store.dart';
import '../../features/memory/archive_thread.dart';
import '../../features/memory/archive_thread_store.dart';
import '../../features/memory/entry_memory_mode.dart';
import '../../services/app_services.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../archive_packs/archive_pack_picker.dart';
import 'entry_memory_scope_picker.dart';
import 'entry_aboutness_picker.dart';
import 'memory_surfacing_picker.dart';
import 'entry_thread_picker.dart';
import 'fresh_next_entry_card.dart';
import 'keep_exact_details_control.dart';
import 'preserve_original_control.dart';

/// Compact entry options on the record screen — memory mode, thread
/// picker, pack picker, and related controls. Collapsed under Advanced
/// save options so the default recording path stays simple.
class EntryOptionsSection extends StatefulWidget {
  const EntryOptionsSection({super.key, this.entryCount = 0});

  final int entryCount;

  @override
  State<EntryOptionsSection> createState() => _EntryOptionsSectionState();
}

class _EntryOptionsSectionState extends State<EntryOptionsSection> {
  List<ArchiveThread> _threads = const [];
  List<ArchivePack> _packs = const [];
  var _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadThreads();
    _loadPacks();
  }

  Future<void> _loadThreads() async {
    if (!AppServices.isInitialized) return;
    final threads = await ArchiveThreadStore.instance().loadAll();
    if (!mounted) return;
    setState(() => _threads = threads);
  }

  Future<void> _loadPacks() async {
    if (!AppServices.isInitialized) return;
    final packs = await ArchivePackStore.instance().loadAll();
    if (!mounted) return;
    setState(() => _packs = packs);
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntryMemoryScopePicker(entryCount: widget.entryCount),
        const SizedBox(height: AppSpacing.sm),
        EntryThreadPicker(threads: _threads, entryCount: widget.entryCount),
        const SizedBox(height: AppSpacing.sm),
        ArchivePackPicker(packs: _packs, entryCount: widget.entryCount),
        const SizedBox(height: AppSpacing.sm),
        KeepExactDetailsControl(entryCount: widget.entryCount),
        const SizedBox(height: AppSpacing.sm),
        PreserveOriginalControl(entryCount: widget.entryCount),
        const SizedBox(height: AppSpacing.sm),
        EntryAboutnessPicker(entryCount: widget.entryCount),
        const SizedBox(height: AppSpacing.sm),
        MemorySurfacingPicker(entryCount: widget.entryCount),
        const SizedBox(height: AppSpacing.sm),
        const FreshNextEntryCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final helperStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.4,
    );

    return Padding(
      key: const Key('entry_options_section'),
      padding: EdgeInsets.only(top: widget.entryCount == 0 ? 0 : 12),
      child: Container(
        width: double.infinity,
        decoration: VoiceMemoryCards.flat(),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('entry_options_expansion'),
            initiallyExpanded: false,
            onExpansionChanged: (value) => setState(() => _expanded = value),
            title: Text(
              EntryMemoryModeCopy.advancedSaveOptionsTitle,
              key: const Key('advanced_save_options_title'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: _expanded
                ? null
                : Text(
                    EntryMemoryModeCopy.advancedSaveOptionsCollapsedHelper,
                    key: const Key('advanced_save_options_helper'),
                    style: helperStyle,
                  ),
            children: _expanded
                ? [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        0,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      child: _content(),
                    ),
                  ]
                : const [],
          ),
        ),
      ),
    );
  }
}
