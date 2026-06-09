import 'package:flutter/material.dart';

import '../../record/start_here_analytics.dart';
import '../../record/start_here_catalog.dart';
import '../../record/start_here_visibility.dart';
import '../../theme/voicememory_colors.dart';

/// Start Here prompts above the record CTA — until first archive milestone.
class StartHereRecordingSection extends StatefulWidget {
  const StartHereRecordingSection({
    super.key,
    required this.recordingCount,
    required this.firstArchiveMilestoneCompleted,
    required this.onPromptSelected,
    this.surface = 'record',
    this.captureMode = 'voice',
  });

  final int recordingCount;
  final bool firstArchiveMilestoneCompleted;
  final ValueChanged<String> onPromptSelected;

  /// Analytics surface id (record, text_capture, empty_archive, …).
  final String surface;

  /// `voice` autostarts recording on record tab; `text` prefills only.
  final String captureMode;

  @override
  State<StartHereRecordingSection> createState() =>
      _StartHereRecordingSectionState();
}

class _StartHereRecordingSectionState extends State<StartHereRecordingSection> {
  bool _shownLogged = false;

  bool get _showStartHere => StartHereVisibility.shouldShowStartHere(
        recordingCount: widget.recordingCount,
        firstArchiveMilestoneCompleted: widget.firstArchiveMilestoneCompleted,
      );

  @override
  void didUpdateWidget(StartHereRecordingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordingCount != widget.recordingCount ||
        oldWidget.firstArchiveMilestoneCompleted !=
            widget.firstArchiveMilestoneCompleted) {
      _shownLogged = false;
    }
  }

  void _logShownIfNeeded() {
    if (_shownLogged || !_showStartHere) return;
    _shownLogged = true;
    StartHereAnalytics.shown(surface: widget.surface);
  }

  void _onTap(String prompt) {
    StartHereAnalytics.selected(
      promptText: prompt,
      surface: widget.surface,
      captureMode: widget.captureMode,
    );
    widget.onPromptSelected(prompt);
  }

  @override
  Widget build(BuildContext context) {
    _logShownIfNeeded();

    if (!_showStartHere) {
      return Semantics(
        label: StartHereCatalog.continueBuildingArchive,
        child: Text(
          StartHereCatalog.continueBuildingArchive,
          key: const Key('start_here_continue_message'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VoiceMemoryColors.textSecondary,
                height: 1.45,
              ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final optionFill = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHighest
        : VoiceMemoryColors.surfaceSecondary;
    final optionBorder = scheme.outline.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const Key('start_here_section'),
      children: [
        Text(
          StartHereCatalog.sectionTitle,
          key: const Key('start_here_section_title'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: VoiceMemoryColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 10),
        Semantics(
          container: true,
          label:
              '${StartHereCatalog.sectionTitle}. ${StartHereCatalog.prompts.length} options.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final prompt in StartHereCatalog.prompts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _StartHereOption(
                    label: prompt,
                    fillColor: optionFill,
                    borderColor: optionBorder,
                    onTap: () => _onTap(prompt),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StartHereOption extends StatelessWidget {
  const _StartHereOption({
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
      label: 'Start here: $label',
      child: Material(
        color: fillColor,
        elevation: 0,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VoiceMemoryColors.textPrimary,
                    height: 1.35,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
