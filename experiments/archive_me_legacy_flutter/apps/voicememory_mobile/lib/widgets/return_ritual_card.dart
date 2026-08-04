import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../features/return_ritual/return_ritual_copy.dart';
import '../features/return_ritual/return_ritual_models.dart';
import '../features/return_ritual/return_ritual_store.dart';

/// Personal return ritual — local choice only, no notifications or streaks.
class ReturnRitualCard extends StatefulWidget {
  const ReturnRitualCard({
    super.key,
    required this.entryCount,
    this.onAddMoment,
    this.store,
    this._initialChoice,
  });

  /// Test hook — skip async prefs load when set.
  const ReturnRitualCard.test({
    super.key,
    required this.entryCount,
    required this._initialChoice,
    this.onAddMoment,
    this.store,
  });

  final int entryCount;
  final VoidCallback? onAddMoment;
  final ReturnRitualStore? store;
  final ReturnRitualChoice? _initialChoice;

  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  State<ReturnRitualCard> createState() => _ReturnRitualCardState();
}

class _ReturnRitualCardState extends State<ReturnRitualCard> {
  ReturnRitualStore? _store;
  ReturnRitualChoice? _choice;
  bool _loading = true;
  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    final initial = widget._initialChoice;
    if (initial != null) {
      _choice = initial.isValid ? initial : null;
      _loading = false;
      _choosing = _choice == null;
      return;
    }
    if (_store == null) {
      _load();
      return;
    }
    _loadFromStore();
  }

  Future<void> _loadFromStore() async {
    final choice = await _store!.load();
    if (!mounted) return;
    setState(() {
      _choice = choice;
      _loading = false;
      _choosing = choice == null;
    });
  }

  Future<void> _load() async {
    _store ??= ReturnRitualStore(AppServices.instance.prefs);
    final choice = await _store!.load();
    if (!mounted) return;
    setState(() {
      _choice = choice;
      _loading = false;
      _choosing = choice == null;
    });
  }

  Future<void> _saveChoice(ReturnRitualChoice choice) async {
    setState(() {
      _choice = choice;
      _choosing = false;
    });
    await _store?.save(choice);
  }

  Future<void> _clearChoice() async {
    setState(() {
      _choice = null;
      _choosing = true;
    });
    await _store?.clear();
  }

  Future<void> _pickCustomPhrase() async {
    final phrase = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CustomPhraseSheet(),
    );
    if (phrase == null || phrase.trim().isEmpty) return;
    await _saveChoice(
      ReturnRitualChoice(
        presetId: ReturnRitualChoice.customPresetId,
        customPhrase: phrase.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entryCount < 1 || _loading) {
      return const SizedBox.shrink(key: Key('return_ritual_card_hidden'));
    }

    final hasChoice = _choice?.isValid == true && !_choosing;
    return Container(
      key: const Key('return_ritual_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ReturnRitualCard._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReturnRitualCard._border),
      ),
      child: hasChoice ? _savedContent(context) : _chooseContent(context),
    );
  }

  Widget _chooseContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ReturnRitualCopy.chooseTitle,
          key: const Key('return_ritual_choose_title'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ReturnRitualCopy.chooseBody,
          key: const Key('return_ritual_choose_body'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final preset in ReturnRitualCopy.presets) ...[
          _OptionButton(
            key: Key('return_ritual_option_${preset.id}'),
            label: preset.phrase,
            onTap: () => _saveChoice(ReturnRitualChoice(presetId: preset.id)),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        _OptionButton(
          key: const Key('return_ritual_option_custom'),
          label: ReturnRitualCopy.customPhraseButton,
          onTap: _pickCustomPhrase,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ReturnRitualCopy.privacyLine,
          key: const Key('return_ritual_privacy_line'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
      ],
    );
  }

  Widget _savedContent(BuildContext context) {
    final phrase = _choice!.resolvePhrase(ReturnRitualCopy.presets);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ReturnRitualCopy.savedTitle,
          key: const Key('return_ritual_saved_title'),
          style: ArchiveMobileTypography.cardLabel(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ReturnRitualCopy.savedComeBackLine(phrase),
          key: const Key('return_ritual_saved_phrase'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ReturnRitualCopy.savedBodyForEntryCount(widget.entryCount),
          key: Key(
            'return_ritual_saved_body_${widget.entryCount >= 5
                ? 'weekly'
                : widget.entryCount >= 3
                ? 'belief'
                : 'default'}',
          ),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton(
              key: const Key('return_ritual_change_button'),
              onPressed: () => setState(() => _choosing = true),
              child: Text(ReturnRitualCopy.changeButton),
            ),
            if (widget.onAddMoment != null)
              FilledButton(
                key: const Key('return_ritual_add_moment_button'),
                onPressed: widget.onAddMoment,
                child: Text(ReturnRitualCopy.addMomentButton),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('return_ritual_clear_button'),
            onPressed: _clearChoice,
            child: Text(ReturnRitualCopy.clearButton),
          ),
        ),
        Text(
          ReturnRitualCopy.privacyLine,
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ReturnRitualCard._border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomPhraseSheet extends StatefulWidget {
  const _CustomPhraseSheet();

  @override
  State<_CustomPhraseSheet> createState() => _CustomPhraseSheetState();
}

class _CustomPhraseSheetState extends State<_CustomPhraseSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ReturnRitualCopy.customPhraseSheetTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('return_ritual_custom_phrase_field'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: ReturnRitualCopy.customPhraseHint,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('return_ritual_custom_phrase_save'),
            onPressed: () => _save(context),
            child: Text(ReturnRitualCopy.customPhraseSave),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ReturnRitualCopy.customPhraseCancel),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }
}
