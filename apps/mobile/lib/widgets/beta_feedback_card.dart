import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_copy.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_engine.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_gates.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Lightweight archive-home beta feedback card — local only, 3+ real entries.
class BetaFeedbackCard extends StatefulWidget {
  const BetaFeedbackCard({
    required this.entries, super.key,
    this.store,
    this.engine = const BetaFeedbackEngine(),
    this.sampleMode = false,
    this.skipPrefsLoad = false,
    this.onChanged,
  }) : _initialState = null;

  const BetaFeedbackCard.test({
    required this.entries, super.key,
    this.store,
    this.engine = const BetaFeedbackEngine(),
    this.sampleMode = false,
    this.onChanged,
    this._initialState,
  }) : skipPrefsLoad = true;

  final List<JournalEntry> entries;
  final BetaFeedbackStore? store;
  final BetaFeedbackEngine engine;
  final bool sampleMode;
  final bool skipPrefsLoad;
  final VoidCallback? onChanged;
  final BetaFeedbackState? _initialState;

  @override
  State<BetaFeedbackCard> createState() => _BetaFeedbackCardState();
}

class _BetaFeedbackCardState extends State<BetaFeedbackCard> {
  BetaFeedbackStore? _store;
  BetaFeedbackState _state = BetaFeedbackState.empty;
  BetaFeedbackUsefulness? _usefulness;
  BetaFeedbackClarity? _clarity;
  final _noteController = TextEditingController();
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _state = widget._initialState ?? BetaFeedbackState.empty;
      _usefulness = _state.usefulness;
      _clarity = _state.clarity;
      if (_state.note case final note?) {
        _noteController.text = note;
      }
      _loading = false;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    _store ??= widget.store ?? BetaFeedbackStore.instance();
    await BetaFeedbackStore.ensureLoaded();
    if (!mounted) return;
    final state = BetaFeedbackStore.cached;
    setState(() {
      _state = state;
      _usefulness = state.usefulness;
      _clarity = state.clarity;
      if (state.note case final note?) {
        _noteController.text = note;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _store ??= widget.store ?? BetaFeedbackStore.instance();
    await _store!.saveResponse(
      usefulness: _usefulness,
      clarity: _clarity,
      note: _noteController.text,
    );
    if (!mounted) return;
    setState(() {
      _saved = true;
      _state = BetaFeedbackStore.cached;
    });
    widget.onChanged?.call();
  }

  Future<void> _dismiss() async {
    _store ??= widget.store ?? BetaFeedbackStore.instance();
    await _store!.dismiss();
    if (!mounted) return;
    setState(() => _state = BetaFeedbackStore.cached);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('beta_feedback_card_loading'));
    }

    final realCount = widget.engine.realEntryCount(widget.entries);
    if (!BetaFeedbackGates.showCard(
      realEntryCount: realCount,
      sampleMode: widget.sampleMode,
      state: _state,
    )) {
      return const SizedBox.shrink(key: Key('beta_feedback_card_hidden'));
    }

    if (_saved) {
      return Text(
        BetaFeedbackCopy.thanksMessage,
        key: const Key('beta_feedback_card_thanks'),
        style: ArchiveMobileTypography.responsiveHelper(context),
      );
    }

    return Container(
      key: const Key('beta_feedback_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            BetaFeedbackCopy.cardTitle,
            key: const Key('beta_feedback_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            BetaFeedbackCopy.cardBody,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _chip(
                key: const Key('beta_feedback_useful'),
                label: BetaFeedbackCopy.usefulnessUseful,
                selected: _usefulness == BetaFeedbackUsefulness.useful,
                onTap: () =>
                    setState(() => _usefulness = BetaFeedbackUsefulness.useful),
              ),
              _chip(
                key: const Key('beta_feedback_not_yet'),
                label: BetaFeedbackCopy.usefulnessNotYet,
                selected: _usefulness == BetaFeedbackUsefulness.notYet,
                onTap: () =>
                    setState(() => _usefulness = BetaFeedbackUsefulness.notYet),
              ),
              _chip(
                key: const Key('beta_feedback_understood'),
                label: BetaFeedbackCopy.clarityUnderstood,
                selected: _clarity == BetaFeedbackClarity.understood,
                onTap: () =>
                    setState(() => _clarity = BetaFeedbackClarity.understood),
              ),
              _chip(
                key: const Key('beta_feedback_confused'),
                label: BetaFeedbackCopy.clarityConfused,
                selected: _clarity == BetaFeedbackClarity.confused,
                onTap: () =>
                    setState(() => _clarity = BetaFeedbackClarity.confused),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('beta_feedback_note'),
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: BetaFeedbackCopy.noteLabel,
              hintText: BetaFeedbackCopy.noteHint,
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
            maxLength: BetaFeedbackStore.maxNoteLength,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('beta_feedback_dismiss'),
                  onPressed: _dismiss,
                  child: const Text(BetaFeedbackCopy.dismissButton),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('beta_feedback_save'),
                  onPressed: (_usefulness != null || _clarity != null)
                      ? _save
                      : null,
                  child: const Text(BetaFeedbackCopy.saveButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      key: key,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}