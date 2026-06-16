import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/user_facing_date.dart';
import '../features/collections/archive_collection.dart';
import '../features/collections/archive_collection_store.dart';
import '../features/entry_detail/entry_detail_copy.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../features/voice_capture/voice_capture_copy.dart';
import '../features/pins/pinned_evidence_store.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../security/private_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/collections/add_to_collection_sheet.dart';
import '../features/action_items/action_item_store.dart';
import '../features/fact_ledger/fact_ledger_store.dart';
import '../widgets/action_items/remember_this_button.dart';
import '../widgets/fact_ledger/save_as_fact_button.dart';
import '../widgets/pins/pin_entry_button.dart';
import '../widgets/memory/entry_aboutness_editor.dart';
import '../widgets/memory/memory_surfacing_editor.dart';
import '../widgets/memory/preserve_original_control.dart';
import '../features/memory/memory_surfacing_mode.dart';
import '../features/memory/sensitive_surfacing_policy.dart';
import '../widgets/pushed_screen_shell.dart';

class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  JournalEntry? _entry;
  bool _advancedExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await AppServices.instance.journalStore.getById(widget.entryId);
    if (e != null) {
      final mode = MemorySurfacingMode.fromEntry(e);
      if (mode.limitsProactiveIntensity) {
        SensitiveSurfacingPolicy.trackUserOpened(
          mode: mode,
          surfaceType: MemorySurfaceType.directOpen,
          source: 'entry_detail',
        );
      }
    }
    if (mounted) setState(() => _entry = e);
  }

  Future<void> _confirmDelete(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(EntryDetailCopy.deleteConfirmTitle),
        content: const Text(EntryDetailCopy.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('entry_detail_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(EntryDetailCopy.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await PrivateDataService(
      journalStore: AppServices.instance.journalStore,
    ).deleteEntrySecurely(entry.id);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/archive-belief');
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _entry;
    return PushedScreenShell(
      title: EntryDetailCopy.title,
      showBottomDone: false,
      body: e == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatUserFacingDate(e.createdAt),
                        style: const TextStyle(
                          color: AppTheme.foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PinEntryButton(
                      entryId: e.id,
                      isPinned: e.isPinned,
                      store: PinnedEvidenceStore.instance(),
                      onChanged: (_) => _load(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  label: EntryDetailCopy.whatYouRecorded,
                  child: _recordedBody(e),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  label: EntryDetailCopy.archiveNoteLabel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        EntryDetailCopy.archiveNoteBody,
                        style: TextStyle(height: 1.45),
                      ),
                      SizedBox(height: 8),
                      Text(
                        EntryDetailCopy.archiveNoteHelper,
                        style: TextStyle(
                          color: AppTheme.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                RememberThisButton(
                  entry: e,
                  store: ActionItemStore.instance(),
                  source: 'entry_detail',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    key: const Key('entry_detail_delete_button'),
                    onPressed: () => _confirmDelete(e),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text(EntryDetailCopy.delete),
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: ExpansionTile(
                    key: const Key('entry_detail_advanced_section'),
                    title: const Text(
                      EntryDetailCopy.advancedDetails,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    initiallyExpanded: _advancedExpanded,
                    onExpansionChanged: (expanded) =>
                        setState(() => _advancedExpanded = expanded),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            EntryAboutnessEditor(entry: e, onChanged: _load),
                            const SizedBox(height: 16),
                            MemorySurfacingEditor(entry: e, onChanged: _load),
                            const SizedBox(height: 16),
                            PreserveOriginalEditor(entry: e, onChanged: _load),
                            const SizedBox(height: 16),
                            SaveAsFactButton(
                              entry: e,
                              store: FactLedgerStore.instance(),
                              source: 'entry_detail',
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              key: const Key('entry_add_to_collection'),
                              onPressed: () => showAddToCollectionSheet(
                                context,
                                store: ArchiveCollectionStore.instance(),
                                entryId: e.id,
                                source: 'entry_detail',
                              ),
                              icon: const Icon(
                                Icons.bookmark_add_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                ArchiveCollectionsCopy.addToCollection,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _recordedBody(JournalEntry entry) {
    final view = entryDetailRecordedView(entry);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          view.primary,
          key: const Key('entry_detail_recorded_body'),
          style: const TextStyle(height: 1.45),
        ),
        if (view.secondary != null) ...[
          const SizedBox(height: 8),
          Text(
            view.secondary!,
            style: const TextStyle(color: AppTheme.muted, height: 1.45),
          ),
        ],
        if (view.isDegradedTranscription) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('entry_detail_type_what_you_said'),
              onPressed: () => context.push(
                '/quick-capture',
                extra: {'entryId': entry.id},
              ),
              child: const Text(VoiceCaptureCopy.typeWhatYouSaid),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionCard({required String label, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
