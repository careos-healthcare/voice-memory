import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/structured_markers/structured_marker_store.dart';
import '../../features/structured_markers/structured_markers.dart';
import '../../theme/app_spacing.dart';
import 'post_save_action_button.dart';

/// The optional ten-second check offered after a moment is already saved.
///
/// Three questions, three taps, all optional. The moment is saved before this
/// card appears, so nothing here can block a save, and every answer can be
/// changed or removed afterwards. There is no score, no streak and no verdict —
/// the reader's own words remain the record and these markers stay secondary
/// to them.
///
/// Nothing on this card is reported to analytics. A strength, an action or an
/// ending is exactly the kind of sensitive label that never leaves the device.
class OptionalStructuredCheckCard extends StatefulWidget {
  const OptionalStructuredCheckCard({
    super.key,
    required this.entryId,
    this.initialMarkers,
    this.onChanged,
  });

  final String entryId;
  final StructuredMarkers? initialMarkers;

  /// Receives every edit and removal. Defaults to the archive's own marker
  /// store, which no-ops safely before services are initialised.
  final ValueChanged<StructuredMarkers>? onChanged;

  @override
  State<OptionalStructuredCheckCard> createState() =>
      _OptionalStructuredCheckCardState();
}

class _OptionalStructuredCheckCardState
    extends State<OptionalStructuredCheckCard> {
  late StructuredMarkers _markers =
      widget.initialMarkers ?? StructuredMarkers(entryId: widget.entryId);
  bool _skipped = false;
  bool _edited = false;

  /// Offered, not imposed. The three questions only appear once the reader asks
  /// for them, or when they already have markers to edit.
  late bool _open = _markers.isNotEmpty;

  /// Markers are read from disk, so they can arrive a frame after this card. Any
  /// answer the reader has already given wins over a late read.
  @override
  void didUpdateWidget(covariant OptionalStructuredCheckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialMarkers;
    if (_edited ||
        incoming == null ||
        identical(incoming, oldWidget.initialMarkers)) {
      return;
    }
    setState(() {
      _markers = incoming;
      _open = _open || incoming.isNotEmpty;
    });
  }

  void _apply(StructuredMarkers next) {
    setState(() {
      _markers = next;
      _edited = true;
    });
    final callback = widget.onChanged;
    if (callback != null) {
      callback(next);
      return;
    }
    unawaited(StructuredMarkerRepository.save(next));
  }

  /// Tapping the selected answer again removes it, so an answer given by
  /// accident is one tap away from being gone.
  void _setStrength(MarkerStrength value) => _apply(
    _markers.strength == value
        ? _markers.copyWith(clearStrength: true, updatedAt: DateTime.now())
        : _markers.copyWith(strength: value, updatedAt: DateTime.now()),
  );

  void _setAction(MarkerAction value) => _apply(
    _markers.action == value
        ? _markers.copyWith(clearAction: true, updatedAt: DateTime.now())
        : _markers.copyWith(action: value, updatedAt: DateTime.now()),
  );

  void _setResolution(MarkerResolution value) => _apply(
    _markers.resolution == value
        ? _markers.copyWith(clearResolution: true, updatedAt: DateTime.now())
        : _markers.copyWith(resolution: value, updatedAt: DateTime.now()),
  );

  @override
  Widget build(BuildContext context) {
    if (_skipped) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      key: const Key('post_save_structured_check'),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                container: true,
                label: 'Optional ten-second check',
                child: ExcludeSemantics(
                  child: Text(
                    'Optional ten-second check',
                    key: const Key('structured_check_header'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              if (_open) ...[
                const SizedBox(height: 6),
                Text(
                  'Your own words stay the record. These markers are optional '
                  'and only give ArchiveMe something extra to compare later.',
                  key: const Key('structured_check_note'),
                  softWrap: true,
                  style: theme.textTheme.bodyMedium,
                ),
                _CheckRow(
                  prompt: StructuredCheckPrompts.strength,
                  options: [
                    for (final value in MarkerStrength.values)
                      PostSaveActionButton(
                        key: Key('structured_check_strength_${value.name}'),
                        label: value.label,
                        selected: _markers.strength == value,
                        onPressed: () => _setStrength(value),
                      ),
                  ],
                ),
                _CheckRow(
                  prompt: StructuredCheckPrompts.action,
                  options: [
                    for (final value in MarkerAction.values)
                      PostSaveActionButton(
                        key: Key('structured_check_action_${value.name}'),
                        label: value.label,
                        selected: _markers.action == value,
                        onPressed: () => _setAction(value),
                      ),
                  ],
                ),
                _CheckRow(
                  prompt: StructuredCheckPrompts.resolution,
                  options: [
                    for (final value in MarkerResolution.values)
                      PostSaveActionButton(
                        key: Key('structured_check_resolution_${value.name}'),
                        label: value.label,
                        selected: _markers.resolution == value,
                        onPressed: () => _setResolution(value),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                children: [
                  if (!_open)
                    PostSaveActionButton(
                      key: const Key('structured_check_open'),
                      label: 'Add markers',
                      onPressed: () => setState(() => _open = true),
                    ),
                  if (_open && _markers.isNotEmpty)
                    PostSaveActionButton(
                      key: const Key('structured_check_remove'),
                      label: 'Remove these markers',
                      outlined: false,
                      onPressed: () =>
                          _apply(_markers.cleared(updatedAt: DateTime.now())),
                    ),
                  PostSaveActionButton(
                    key: const Key('structured_check_skip'),
                    label: 'Skip this',
                    outlined: false,
                    onPressed: () => setState(() => _skipped = true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.prompt, required this.options});

  final String prompt;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          label: prompt,
          child: ExcludeSemantics(
            child: Text(
              prompt,
              softWrap: true,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: AppSpacing.xs, runSpacing: 4, children: options),
      ],
    ),
  );
}
