import 'package:flutter/material.dart';

import '../../features/routine/routine_anchor_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Lets the user attach tomorrow's check to one moment in their day.
///
/// This is a plain planning helper — it picks a label, it does not schedule any
/// real reminder.
class RoutineAnchorChooser extends StatefulWidget {
  const RoutineAnchorChooser({super.key, required this.onSelected});

  /// Fires with the chosen anchor.
  final void Function(RoutineAnchor anchor) onSelected;

  static const String title = 'When should ArchiveMe ask this?';
  static const String subtitle =
      'Pick a moment in your day. This makes tomorrow\u2019s check easier to '
      'remember.';

  /// Shows the chooser in a bottom sheet and returns the chosen anchor, or null
  /// if dismissed.
  static Future<RoutineAnchor?> show(BuildContext context) {
    return showModalBottomSheet<RoutineAnchor>(
      context: context,
      backgroundColor: const Color(0xFFFFFBF5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: RoutineAnchorChooser(
            onSelected: (anchor) => Navigator.of(sheetContext).pop(anchor),
          ),
        ),
      ),
    );
  }

  @override
  State<RoutineAnchorChooser> createState() => _RoutineAnchorChooserState();
}

class _RoutineAnchorChooserState extends State<RoutineAnchorChooser> {
  static const Color _warmBorder = Color(0xFFF5E6D3);

  final TextEditingController _customController = TextEditingController();
  bool _customOpen = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _pick(RoutineAnchorType type) {
    if (type == RoutineAnchorType.custom) {
      setState(() => _customOpen = true);
      return;
    }
    widget.onSelected(RoutineAnchor(type: type));
  }

  void _confirmCustom() {
    final label = _customController.text.trim();
    widget.onSelected(
      RoutineAnchor(
        type: RoutineAnchorType.custom,
        customLabel: label.isEmpty ? null : label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RoutineAnchorChooser.title,
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 17),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          RoutineAnchorChooser.subtitle,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final type in RoutineAnchorType.values)
              _AnchorChip(label: type.label, onTap: () => _pick(type)),
          ],
        ),
        if (_customOpen) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _customController,
            autofocus: true,
            onSubmitted: (_) => _confirmCustom(),
            decoration: InputDecoration(
              hintText: 'Name a moment in your day',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _warmBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _warmBorder),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _confirmCustom,
              child: const Text('Use this moment'),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnchorChip extends StatelessWidget {
  const _AnchorChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      labelStyle: VoiceMemoryTypography.bodyStyle(
        color: AppColors.textPrimary,
      ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFF5E6D3)),
      ),
    );
  }
}
