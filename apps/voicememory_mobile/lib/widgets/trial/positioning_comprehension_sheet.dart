import 'package:flutter/material.dart';

import '../../config/trial_mode.dart';
import '../../features/trial/positioning_comprehension_model.dart';
import '../../features/trial/positioning_comprehension_store.dart';
import '../../theme/app_spacing.dart';

/// Trial-only survey: did the user understand ArchiveMe as pattern memory?
abstract final class PositioningComprehensionSheet {
  PositioningComprehensionSheet._();

  static Future<void> showIfEligible(BuildContext context) async {
    if (!TrialMode.enabled) return;
    final store = PositioningComprehensionStore.instance();
    if (await store.hasAnswered()) return;
    if (!context.mounted) return;
    await show(context);
  }

  static Future<void> show(BuildContext context) async {
    await PositioningComprehensionStore.instance().markAsked();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _PositioningComprehensionSheetBody(),
    );
  }
}

class _PositioningComprehensionSheetBody extends StatefulWidget {
  const _PositioningComprehensionSheetBody();

  @override
  State<_PositioningComprehensionSheetBody> createState() =>
      _PositioningComprehensionSheetBodyState();
}

class _PositioningComprehensionSheetBodyState
    extends State<_PositioningComprehensionSheetBody> {
  PositioningComprehensionAnswer? _selected;
  final _followUpController = TextEditingController();
  bool _showFollowUp = false;
  bool _saving = false;

  @override
  void dispose() {
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final answer = _selected;
    if (answer == null || _saving) return;
    setState(() => _saving = true);
    await PositioningComprehensionStore.instance().recordAnswer(
      answer,
      followUp: _followUpController.text.trim().isEmpty
          ? null
          : _followUpController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PositioningComprehensionCopy.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final answer in PositioningComprehensionAnswer.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _selected = answer;
                          _showFollowUp = true;
                        }),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _selected == answer
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.35)
                      : null,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(PositioningComprehensionCopy.labelFor(answer)),
              ),
            ),
          if (_showFollowUp) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              PositioningComprehensionCopy.followUpQuestion,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _followUpController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Optional',
              ),
              maxLines: 2,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _selected == null || _saving ? null : _submit,
            child: Text(_saving ? 'Saving…' : 'Submit'),
          ),
        ],
      ),
    );
  }
}
