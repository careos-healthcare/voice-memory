import 'package:archiveme_mobile/core/config/beta_surfaces_feature_flags.dart';
import 'package:archiveme_mobile/features/recording/recording_mode.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Switches between passive journaling and live AI conversation on Record.
class RecordingModeToggle extends StatelessWidget {
  const RecordingModeToggle({
    required this.mode, required this.onChanged, super.key,
  });

  final RecordingMode mode;
  final ValueChanged<RecordingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!BetaSurfacesFeatureFlags.liveConversation) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Recording mode',
      child: SegmentedButton<RecordingMode>(
        key: const Key('recording_mode_toggle'),
        segments: RecordingMode.values
            .map(
              (value) => ButtonSegment<RecordingMode>(
                value: value,
                label: Text(value.toggleLabel),
              ),
            )
            .toList(),
        selected: {mode},
        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;
          onChanged(selection.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return VoiceMemoryColors.primaryIndigo;
            }
            return VoiceMemoryColors.textSecondary;
          }),
        ),
      ),
    );
  }
}