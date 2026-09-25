import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_entry_hero_tags.dart';
import 'package:archiveme_mobile/features/entry_detail/entry_detail_copy.dart';
import 'package:archiveme_mobile/features/entry_detail/entry_detail_edits.dart';
import 'package:archiveme_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:archiveme_mobile/features/memory/sensitive_surfacing_policy.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_palette.dart';
import 'package:archiveme_mobile/widgets/archive/entry_context_tag_editor.dart';
import 'package:archiveme_mobile/widgets/entry/entry_audio_player.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_context_placeholders.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_processing_trust_chip.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_read_aloud_button.dart';
import 'package:archiveme_mobile/widgets/memory/entry_aboutness_editor.dart';
import 'package:archiveme_mobile/widgets/memory/memory_surfacing_editor.dart';
import 'package:archiveme_mobile/widgets/memory/preserve_original_control.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({
    required this.entryId,
    super.key,
    this.accountDependencies,
    this.previewEntry,
  });

  final String entryId;

  final V1AccountDependencies? accountDependencies;

  /// Skips journal loading so a golden can paint the screen without AppServices.
  @visibleForTesting
  final JournalEntry? previewEntry;

  /// When set, Edit date and time writes this instant instead of opening pickers.
  @visibleForTesting
  static DateTime? debugCreatedAtOverride;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  JournalEntry? _entry;
  bool _advancedExpanded = false;
  Future<void> Function()? _readAloud;
  late final TextEditingController _titleController;

  V1AccountDependencies get _accountDeps =>
      widget.accountDependencies ?? V1AccountDependencies.fromAppServices();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    final preview = widget.previewEntry;
    if (preview != null) {
      _entry = preview;
      _titleController.text = preview.display.title ?? '';
      return;
    }
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
      if (mounted) {
        setState(() => _entry = loaded);
        _titleController.text = loaded?.display.title ?? '';
      }
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
    if (mounted) {
      setState(() => _entry = e);
      _titleController.text = e?.display.title ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _savePlace(JournalEntry entry, String place) async {
    if (widget.previewEntry != null) return;
    await saveEntryPlace(
      store: _accountDeps.journalStore,
      entry: entry,
      place: place,
    );
    await _load();
  }

  Future<void> _saveMood(JournalEntry entry, String mood) async {
    if (widget.previewEntry != null) return;
    await saveEntryMood(
      store: _accountDeps.journalStore,
      entry: entry,
      mood: mood,
    );
    await _load();
  }

  Future<void> _saveTitle(JournalEntry entry) async {
    if (widget.previewEntry != null) return;
    await saveEntryTitle(
      store: _accountDeps.journalStore,
      entry: entry,
      title: _titleController.text,
    );
    await _load();
  }

  Future<void> _editDate(JournalEntry entry) async {
    if (widget.previewEntry != null) return;
    final override = EntryDetailScreen.debugCreatedAtOverride;
    DateTime? next = override;
    if (next == null) {
      final date = await showDatePicker(
        context: context,
        initialDate: entry.createdAt,
        firstDate: DateTime(1970),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(entry.createdAt),
      );
      if (time == null || !mounted) return;
      next = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
    await saveEntryCreatedAt(
      store: _accountDeps.journalStore,
      entry: entry,
      createdAt: next,
    );
    await _load();
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
      title: e == null
          ? EntryDetailCopy.title
          : LocaleDateFormat.dateTime(context, e.createdAt),
      showBottomDone: false,
      actions: e == null
          ? null
          : [
              PopupMenuButton<String>(
                key: const Key('entry_detail_overflow'),
                tooltip: 'More',
                onSelected: (value) {
                  if (value == 'date') unawaited(_editDate(e));
                  if (value == 'read') unawaited(_readAloud?.call());
                  if (value == 'delete') unawaited(_confirmDelete(e));
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'date',
                    child: Text(EntryDetailCopy.editDateTime),
                  ),
                  if (_readAloud != null)
                    const PopupMenuItem(
                      value: 'read',
                      child: Text(EntryDetailCopy.readAloud),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(EntryDetailCopy.delete),
                  ),
                ],
              ),
            ],
      body: e == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  _quietMeta(context, e),
                  key: const Key('entry_detail_meta'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                EntryProcessingTrustChip(entry: e),
                const SizedBox(height: 12),
                EntryContextPlaceholders(
                  entry: e,
                  onPlace: widget.previewEntry == null
                      ? (place) => unawaited(_savePlace(e, place))
                      : null,
                  onMood: widget.previewEntry == null
                      ? (mood) => unawaited(_saveMood(e, mood))
                      : null,
                ),
                const SizedBox(height: 16),
                Hero(
                  tag: ArchiveEntryHeroTags.surface(widget.entryId),
                  child: Material(
                    color: Colors.transparent,
                    child: _recordedBody(e),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.accountDependencies != null)
                  EntryContextTagEditor(
                    entry: e,
                    journalStore: _accountDeps.journalStore,
                    onChanged: _load,
                  ),
                const SizedBox(height: 16),
                Material(
                  color: context.palette.backgroundSecondary,
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
        TextField(
          key: const Key('entry_detail_title'),
          controller: _titleController,
          style: ArchiveMobileTypography.userWords(context).copyWith(
            fontSize: 32,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: 'Add a title',
            hintStyle: ArchiveMobileTypography.userWords(context).copyWith(
              fontSize: 32,
              height: 1.2,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.38,
              ),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => unawaited(_saveTitle(entry)),
        ),
        const SizedBox(height: 8),
        EntryAudioPlayer(
          audioPath: entry.localAudioPath,
          durationSeconds: entry.durationSeconds,
        ),
        const SizedBox(height: 8),
        Text(
          view.primary,
          key: const Key('entry_detail_recorded_body'),
          style: ArchiveMobileTypography.userWords(context).copyWith(
            height: 1.55,
          ),
        ),
        if (speakableText != null && widget.accountDependencies != null)
          Offstage(
            child: EntryReadAloudButton(
              text: speakableText,
              visible: false,
              offlineTts: _accountDeps.offlineTts,
              registerToggle: (toggle) {
                _readAloud = toggle;
                if (mounted) setState(() {});
              },
              resolveOfflineTts: _isFlutterWidgetTest
                  ? null
                  : () => AppServices.instance.resolveOfflineTts(),
            ),
          ),
        if (view.secondary != null) ...[
          const SizedBox(height: 8),
          Text(
            view.secondary!,
            style: ArchiveMobileTypography.uiHelper(
              context,
              color: context.palette.textSecondary,
            ),
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

  String _quietMeta(BuildContext context, JournalEntry entry) {
    final minutes = entry.durationSeconds ~/ 60;
    final seconds = entry.durationSeconds % 60;
    final duration = '$minutes:${seconds.toString().padLeft(2, '0')}';
    return '$duration · ${_languageName(context)}';
  }

  String _languageName(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    return switch (code) {
      'es' => 'Spanish',
      'hi' => 'Hindi',
      'ms' => 'Malay',
      'ta' => 'Tamil',
      'zh' => 'Chinese',
      _ => 'English',
    };
  }
}
