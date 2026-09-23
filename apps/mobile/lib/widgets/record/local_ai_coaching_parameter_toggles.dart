import 'package:archiveme_mobile/features/playback/local_ai_coach.dart';
import 'package:flutter/material.dart';

/// Advanced on-device coaching switches for the entry form.
///
/// Hidden until [successfulEntryCount] reaches [revealAfterSuccessfulEntries].
class LocalAiCoachingParameterToggles extends StatelessWidget {
  const LocalAiCoachingParameterToggles({
    required this.successfulEntryCount,
    required this.parameters,
    required this.onChanged,
    super.key,
  });

  /// Saved moments required before these switches appear.
  static const revealAfterSuccessfulEntries = 3;

  final int successfulEntryCount;
  final LocalAiCoachingParameters parameters;
  final ValueChanged<LocalAiCoachingParameters> onChanged;

  static bool visibleForEntryCount(int successfulEntryCount) {
    return successfulEntryCount >= revealAfterSuccessfulEntries;
  }

  @override
  Widget build(BuildContext context) {
    if (!visibleForEntryCount(successfulEntryCount)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Column(
      key: const Key('local_ai_coaching_parameters'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'On-device coaching',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Optional readings for playback. They stay on this device.',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
        ),
        SwitchListTile(
          key: const Key('local_ai_coaching_notice_pauses'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Notice pauses'),
          subtitle: const Text('Mark a long pause before speech.'),
          value: parameters.noticePauses,
          onChanged: (value) =>
              onChanged(parameters.copyWith(noticePauses: value)),
        ),
        SwitchListTile(
          key: const Key('local_ai_coaching_keep_quiet'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Keep quiet stretches'),
          subtitle: const Text('Leave the quiet part in the reading.'),
          value: parameters.keepQuietStretches,
          onChanged: (value) =>
              onChanged(parameters.copyWith(keepQuietStretches: value)),
        ),
        SwitchListTile(
          key: const Key('local_ai_coaching_short_note'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Write a short note'),
          subtitle: const Text('Add one line about how playback felt.'),
          value: parameters.writeShortNote,
          onChanged: (value) =>
              onChanged(parameters.copyWith(writeShortNote: value)),
        ),
      ],
    );
  }
}
