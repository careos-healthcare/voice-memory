import 'package:archiveme_mobile/record/example_prompt_analytics.dart';
import 'package:archiveme_mobile/record/example_prompt_catalog.dart';
import 'package:archiveme_mobile/record/example_prompt_visibility.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Conversation starters for first-time capture — compact chips, wraps on narrow screens.
class ExamplePromptChips extends StatefulWidget {
  const ExamplePromptChips({
    required this.recordingCount, required this.firstArchiveMilestoneCompleted, required this.onPromptSelected, super.key,
    this.surface = 'record',
  });

  final int recordingCount;
  final bool firstArchiveMilestoneCompleted;
  final ValueChanged<String> onPromptSelected;

  /// Analytics surface id (record, empty_archive, first_reflection, text_capture, …).
  final String surface;

  @override
  State<ExamplePromptChips> createState() => _ExamplePromptChipsState();
}

class _ExamplePromptChipsState extends State<ExamplePromptChips> {
  bool _shownLogged = false;

  bool get _showPrompts => ExamplePromptVisibility.shouldShowExamplePrompts(
    recordingCount: widget.recordingCount,
    firstArchiveMilestoneCompleted: widget.firstArchiveMilestoneCompleted,
  );

  @override
  void didUpdateWidget(ExamplePromptChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordingCount != widget.recordingCount ||
        oldWidget.firstArchiveMilestoneCompleted !=
            widget.firstArchiveMilestoneCompleted) {
      _shownLogged = false;
    }
  }

  void _logShownIfNeeded() {
    if (_shownLogged || !_showPrompts) return;
    _shownLogged = true;
    unawaited(ExamplePromptAnalytics.shown(surface: widget.surface));
  }

  void _onTap(String prompt) {
    final mode = widget.surface == 'text_capture' ? 'text' : 'voice';
    unawaited(ExamplePromptAnalytics.tapped(
      promptText: prompt,
      surface: widget.surface,
      captureMode: mode,
    ));
    widget.onPromptSelected(prompt);
  }

  @override
  Widget build(BuildContext context) {
    _logShownIfNeeded();

    if (!_showPrompts) {
      return Semantics(
        label: ExamplePromptCatalog.continueBuildingArchive,
        child: Text(
          ExamplePromptCatalog.continueBuildingArchive,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: VoiceMemoryColors.textSecondary,
            height: 1.45,
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final chipFill = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHighest
        : VoiceMemoryColors.surfaceSecondary;
    final chipBorder = scheme.outline.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ExamplePromptCatalog.sectionTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: VoiceMemoryColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          container: true,
          label:
              '${ExamplePromptCatalog.sectionTitle}. ${ExamplePromptCatalog.prompts.length} conversation starters.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in ExamplePromptCatalog.prompts)
                _ExamplePromptChip(
                  label: prompt,
                  fillColor: chipFill,
                  borderColor: chipBorder,
                  onTap: () => _onTap(prompt),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExamplePromptChip extends StatelessWidget {
  const _ExamplePromptChip({
    required this.label,
    required this.fillColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final Color fillColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Conversation starter: $label',
      child: Material(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VoiceMemoryColors.textPrimary,
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}