import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_copy.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Sheet for renaming a grounded pattern label — display only.
class RenamePatternSheet extends StatefulWidget {
  const RenamePatternSheet({
    required this.initialName, required this.onSave, super.key,
  });

  final String initialName;
  final Future<void> Function(String name) onSave;

  static Future<bool?> show(
    BuildContext context, {
    required String initialName,
    required Future<void> Function(String name) onSave,
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
        child: RenamePatternSheet(initialName: initialName, onSave: onSave),
      ),
    );
  }

  @override
  State<RenamePatternSheet> createState() => _RenamePatternSheetState();
}

class _RenamePatternSheetState extends State<RenamePatternSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final normalized = PatternNameStore.sanitizeCustomName(_controller.text);
    if (normalized == null) return;
    await widget.onSave(normalized);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

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
              PatternNameCopy.renameSheetTitle,
              key: const Key('rename_pattern_sheet_title'),
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              PatternNameCopy.renameSheetHelper,
              key: const Key('rename_pattern_sheet_helper'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('rename_pattern_field'),
              controller: _controller,
              decoration: const InputDecoration(
                labelText: PatternNameCopy.renameFieldLabel,
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('rename_pattern_save_button'),
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text(PatternNameCopy.saveNameCta),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('rename_pattern_cancel_button'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(PatternNameCopy.cancelCta),
            ),
          ],
        ),
      ),
    );
  }
}