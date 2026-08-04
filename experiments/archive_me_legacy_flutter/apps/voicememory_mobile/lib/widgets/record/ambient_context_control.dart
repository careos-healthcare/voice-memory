import 'package:flutter/material.dart';

import '../../models/local_capture_context.dart';
import '../../theme/app_spacing.dart';

class AmbientContextRequest {
  const AmbientContextRequest({
    required this.includeLocation,
    required this.includeCalendarEvent,
  });

  final bool includeLocation;
  final bool includeCalendarEvent;
}

Future<AmbientContextRequest?> showAmbientContextConsentSheet(
  BuildContext context,
) {
  var includeLocation = true;
  var includeCalendarEvent = true;
  return showModalBottomSheet<AmbientContextRequest>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add local context',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'ArchiveMe keeps only the selected place label or current '
                'event name on this device. Raw coordinates, calendar IDs, '
                'attendees, and event details are never retained or uploaded.',
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Current area'),
                subtitle: const Text('A coarse city or region label only'),
                value: includeLocation,
                onChanged: (value) =>
                    setSheetState(() => includeLocation = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Current calendar event'),
                subtitle: const Text('The title of an event happening now'),
                value: includeCalendarEvent,
                onChanged: (value) =>
                    setSheetState(() => includeCalendarEvent = value ?? false),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: includeLocation || includeCalendarEvent
                    ? () => Navigator.of(context).pop(
                        AmbientContextRequest(
                          includeLocation: includeLocation,
                          includeCalendarEvent: includeCalendarEvent,
                        ),
                      )
                    : null,
                child: const Text('Add selected context'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AmbientContextControl extends StatelessWidget {
  const AmbientContextControl({
    super.key,
    required this.contextMetadata,
    required this.loading,
    required this.onAdd,
    required this.onClear,
  });

  final LocalCaptureContext? contextMetadata;
  final bool loading;
  final VoidCallback onAdd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final metadata = contextMetadata;
    return Semantics(
      container: true,
      label: 'Optional local capture context',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metadata != null && !metadata.isEmpty)
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (metadata.locationLabel != null)
                  Chip(
                    avatar: const Icon(Icons.location_on_outlined, size: 18),
                    label: Text(metadata.locationLabel!),
                  ),
                if (metadata.calendarEventName != null)
                  Chip(
                    avatar: const Icon(Icons.event_outlined, size: 18),
                    label: Text(metadata.calendarEventName!),
                  ),
              ],
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: const Key('ambient_context_add_button'),
                onPressed: loading ? null : onAdd,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt_outlined),
                label: Text(
                  metadata == null ? 'Add local context' : 'Change context',
                ),
              ),
              if (metadata != null)
                TextButton(
                  key: const Key('ambient_context_clear_button'),
                  onPressed: loading ? null : onClear,
                  child: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
