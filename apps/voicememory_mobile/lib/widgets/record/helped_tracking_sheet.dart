import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/helped_tracking/helped_tracking_copy.dart';
import '../../features/helped_tracking/helped_tracking_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Sheet for free-text helped evidence — stays local/private.
class HelpedTrackingSheet extends StatefulWidget {
  const HelpedTrackingSheet({super.key, required this.onSave});

  final Future<void> Function(String text) onSave;

  static Future<bool?> show(
    BuildContext context, {
    required Future<void> Function(String text) onSave,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: HelpedTrackingSheet(onSave: onSave),
      ),
    );
  }

  @override
  State<HelpedTrackingSheet> createState() => _HelpedTrackingSheetState();
}

class _HelpedTrackingSheetState extends State<HelpedTrackingSheet> {
  late final TextEditingController _controller;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final normalized = HelpedTrackingStore.sanitizeFreeText(_controller.text);
    if (normalized == null || _saving) return;
    setState(() => _saving = true);
    await widget.onSave(normalized);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              HelpedTrackingCopy.sheetTitle,
              key: const Key('helped_tracking_sheet_title'),
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('helped_tracking_sheet_field'),
              controller: _controller,
              decoration: const InputDecoration(
                labelText: HelpedTrackingCopy.sheetFieldLabel,
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('helped_tracking_sheet_save'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
              ),
              child: Text(_saving ? 'Saving…' : HelpedTrackingCopy.saveCta),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('helped_tracking_sheet_cancel'),
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text(HelpedTrackingCopy.cancelCta),
            ),
          ],
        ),
      ),
    );
  }
}
