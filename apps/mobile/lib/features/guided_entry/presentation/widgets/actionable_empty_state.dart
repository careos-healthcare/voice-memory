import 'dart:async';

import 'package:archiveme_mobile/core/services/activity_metadata_service.dart';
import 'package:archiveme_mobile/core/services/rich_import_permission_client.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/controllers/entry_controller.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/rich_import_copy.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/time_of_day_prompt.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/providers/time_of_day_prompt_provider.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/widgets/activity_picker_sheet.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/widgets/soft_permission_overlay.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Blank-entry prompt plus one-tap photo, location, and activity chips.
class ActionableEmptyState extends ConsumerStatefulWidget {
  const ActionableEmptyState({
    super.key,
    this.onDraftCreated,
    this.compact = false,
  });

  final ValueChanged<JournalEntry>? onDraftCreated;

  /// Title and chips only, for the short focused capture card.
  final bool compact;

  @override
  ConsumerState<ActionableEmptyState> createState() =>
      _ActionableEmptyStateState();
}

class _ActionableEmptyStateState extends ConsumerState<ActionableEmptyState> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final prompt = ref.watch(timeOfDayPromptProvider);
    final theme = Theme.of(context);
    return Column(
      key: const Key('actionable_empty_state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prompt.title,
          key: const Key('time_of_day_prompt_title'),
          style: theme.textTheme.titleMedium,
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 4),
          Text(prompt.body, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              key: const Key('rich_import_photo_chip'),
              avatar: const Icon(Icons.photo_outlined, size: 18),
              label: const Text(RichImportCopy.addRecentPhoto),
              onPressed: _busy ? null : () => unawaited(_importPhoto(prompt)),
            ),
            ActionChip(
              key: const Key('rich_import_location_chip'),
              avatar: const Icon(Icons.place_outlined, size: 18),
              label: const Text(RichImportCopy.attachLocation),
              onPressed: _busy
                  ? null
                  : () => unawaited(_importLocation(prompt)),
            ),
            ActionChip(
              key: const Key('rich_import_activity_chip'),
              avatar: const Icon(Icons.directions_walk, size: 18),
              label: const Text(RichImportCopy.logCurrentActivity),
              onPressed: _busy
                  ? null
                  : () => unawaited(_importActivity(prompt)),
            ),
          ],
        ),
      ],
    );
  }

  Future<bool> _consent(SoftPermissionKind kind) {
    if (!mounted) return Future<bool>.value(false);
    return SoftPermissionOverlay.show(context, kind);
  }

  Future<ActivityMetadata?> _pickActivity() {
    if (!mounted) return Future<ActivityMetadata?>.value();
    return ActivityPickerSheet.show(context);
  }

  Future<void> _importPhoto(TimeOfDayPrompt prompt) {
    final controller = ref.read(entryControllerProvider);
    return _run(
      () => controller.importRecentPhoto(
        prompt: prompt,
        requestSoftConsent: _consent,
      ),
    );
  }

  Future<void> _importLocation(TimeOfDayPrompt prompt) {
    final controller = ref.read(entryControllerProvider);
    return _run(
      () => controller.importCurrentLocation(
        prompt: prompt,
        requestSoftConsent: _consent,
      ),
    );
  }

  Future<void> _importActivity(TimeOfDayPrompt prompt) {
    final controller = ref.read(entryControllerProvider);
    return _run(
      () => controller.importCurrentActivity(
        prompt: prompt,
        pick: _pickActivity,
      ),
    );
  }

  Future<void> _run(Future<ImportResult> Function() action) async {
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted) return;
      switch (result) {
        case ImportCreated(:final entry):
          widget.onDraftCreated?.call(entry);
        case ImportFailed(:final message):
          await RichImportFailureOverlay.show(context, message);
        case ImportCancelled():
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
