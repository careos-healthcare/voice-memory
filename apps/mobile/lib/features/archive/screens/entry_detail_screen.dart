import 'dart:io';

import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_entry_hero_tags.dart';
import 'package:archiveme_mobile/features/entry_detail/entry_detail_copy.dart';
import 'package:archiveme_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:archiveme_mobile/features/memory/sensitive_surfacing_policy.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_processing_trust_chip.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:archiveme_mobile/widgets/archive/entry_context_tag_editor.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_read_aloud_button.dart';
import 'package:archiveme_mobile/widgets/memory/entry_aboutness_editor.dart';
import 'package:archiveme_mobile/widgets/memory/memory_surfacing_editor.dart';
import 'package:archiveme_mobile/widgets/memory/preserve_original_control.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({
    required this.entryId, super.key,
    this.accountDependencies,
  });

  final String entryId;

  final V1AccountDependencies? accountDependencies;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  JournalEntry? _entry;
  bool _advancedExpanded = false;

  late final V1AccountDependencies _accountDeps =
      widget.accountDependencies ?? V1AccountDependencies.fromAppServices();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  bool get _isFlutterWidgetTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> _load() async {
    if (_isFlutterWidgetTest) {
      JournalEntry? loaded;
      for (final entry in _accountDeps.journalStore.loadAllSync()) {
        if (entry.id == widget.entryId) {
          loaded = entry;
          break;
        }
      }
      if (mounted) setState(() => _entry = loaded);
      return;
    }

    final e = await _accountDeps.journalStore.getById(widget.entryId);
    if (e != null) {
      final mode = MemorySurfacingMode.fromEntry(e);
      if (mode.limitsProactiveIntensity) {
        SensitiveSurfacingPolicy.trackUserOpened(
          mode: mode,
          surfaceType: MemorySurfaceType.directOpen,
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
      journalStore: _accountDeps.journalStore,
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
                ArchiveEntryCardMeta(entry: e),
                EntryProcessingTrustChip(entry: e),
                const SizedBox(height: 16),
                Hero(
                  tag: ArchiveEntryHeroTags.surface(widget.entryId),
                  child: Material(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: _sectionCard(
                      label: EntryDetailCopy.whatYouRecorded,
                      child: _recordedBody(e),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  label: EntryDetailCopy.archiveNoteLabel,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        EntryDetailCopy.archiveNoteBody,
                        style: TextStyle(height: 1.45),
                      ),
                      SizedBox(height: 8),
                      Text(
                        EntryDetailCopy.archiveNoteHelper,
                        style: TextStyle(color: AppTheme.muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                EntryContextTagEditor(
                  entry: e,
                  journalStore: _accountDeps.journalStore,
                  onChanged: _load,
                ),
                const SizedBox(height: 16),
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
    final speakableText = entrySpeakableText(entry);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          view.primary,
          key: const Key('entry_detail_recorded_body'),
          style: const TextStyle(height: 1.45),
        ),
        if (speakableText != null) ...[
          const SizedBox(height: 8),
          EntryReadAloudButton(
            text: speakableText,
            offlineTts: _accountDeps.offlineTts,
            resolveOfflineTts: _isFlutterWidgetTest
                ? null
                : () => AppServices.instance.resolveOfflineTts(),
          ),
        ],
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
              onPressed: () =>
                  context.push('/quick-capture', extra: {'entryId': entry.id}),
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