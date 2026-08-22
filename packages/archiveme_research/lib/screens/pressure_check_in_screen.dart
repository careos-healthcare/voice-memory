import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_option.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_service.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_context.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/memory/fresh_entry_choice.dart';
import 'package:archiveme_mobile/widgets/prove_enough/prove_enough_post_record_payoff.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/ask_the_archive_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_first_win_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_quick_save_success.dart';

/// One-tap pressure check-in: pick a pressure, quick save, see the payoff.
class PressureCheckInScreen extends StatefulWidget {
  const PressureCheckInScreen({super.key, this.service});

  /// Injected for tests; production uses [PressureCheckInService.instance].
  final PressureCheckInService? service;

  @override
  State<PressureCheckInScreen> createState() => _PressureCheckInScreenState();
}

class _PressureCheckInScreenState extends State<PressureCheckInScreen> {
  PressureCheckInOption? _selected;
  final Set<PressureContext> _contexts = {};
  final TextEditingController _fear = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _choseToStop = false;
  bool _saving = false;
  PressureCheckInSaveResult? _saved;

  late final LoopMode _proveEnoughLoop;
  late final FirstSessionPattern _payoffPattern;

  @override
  void initState() {
    super.initState();
    _proveEnoughLoop = const LoopModeEngine().activate(LoopModeIds.proveEnough);
    _payoffPattern = _buildPayoffPattern();
  }

  @override
  void dispose() {
    _fear.dispose();
    _note.dispose();
    super.dispose();
  }

  /// [withoutConnecting] saves the moment with no connection signals
  /// attached (no contexts, no free text) — the raw choice is still kept,
  /// it just cannot be pulled into old patterns.
  Future<void> _quickSave({bool withoutConnecting = false}) async {
    final option = _selected;
    if (option == null || _saving) return;
    setState(() => _saving = true);

    final service = widget.service ?? PressureCheckInService.instance();
    final result = await service.save(
      option: option,
      contexts: withoutConnecting ? const [] : _contexts.toList(),
      fear: withoutConnecting ? '' : _fear.text,
      stopCostNote: withoutConnecting ? '' : _note.text,
      choseToStop: _choseToStop,
    );

    if (!mounted) return;
    setState(() {
      _saved = result;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Log a pressure moment'),
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: saved == null
              ? _buildForm(context)
              : _buildPostSave(context, saved),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What pressure just showed up?',
          style: ArchiveMobileTypography.responsivePageTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pick the closest. One tap is enough — the rest is optional.',
          style: ArchiveMobileTypography.body(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final option in PressureCheckInOption.values) ...[
          _OptionTile(
            option: option,
            selected: _selected == option,
            onTap: () => setState(() => _selected = option),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (_selected != null) ...[
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const Key('pressure_quick_save_cta'),
              onPressed: _saving ? null : _quickSave,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_outlined),
              label: const Text('Quick save'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildOptionalSection(context),
          const SizedBox(height: AppSpacing.sm),
          // Memory stays optional: this save never has to join a thread.
          FreshEntryChoice(
            onSaveWithoutConnecting: () => _quickSave(withoutConnecting: true),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionalSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add context (optional)',
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final context in PressureContext.values)
                FilterChip(
                  label: Text(context.label),
                  selected: _contexts.contains(context),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _contexts.add(context);
                    } else {
                      _contexts.remove(context);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('pressure_fear_field'),
            controller: _fear,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What did you fear would happen if you stopped?',
              hintText: 'Optional',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('pressure_note_field'),
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Stop-cost note',
              hintText: 'Optional',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile.adaptive(
            key: const Key('pressure_chose_to_stop_switch'),
            contentPadding: EdgeInsets.zero,
            value: _choseToStop,
            onChanged: (value) => setState(() => _choseToStop = value),
            title: Text(
              'I chose to stop this time',
              style: ArchiveMobileTypography.body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostSave(BuildContext context, PressureCheckInSaveResult saved) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saved.isFirst)
          PressureFirstWinCard(
            onSeeMeaning: () => context.push('/pressure-insights'),
          )
        else
          const PressureQuickSaveSuccess(),
        const SizedBox(height: AppSpacing.sm),
        ProveEnoughPostRecordPayoff(
          entryId: saved.entry.id,
          entry: saved.entry,
          activeLoop: _proveEnoughLoop,
          pattern: _payoffPattern,
          includeRetentionPanel: false,
        ),
        const SizedBox(height: AppSpacing.sm),
        AskTheArchiveCard(records: [saved.record]),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: () => context.push('/pressure-insights'),
          child: const Text('See your pressure loop'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => setState(() {
            _saved = null;
            _selected = null;
            _contexts.clear();
            _fear.clear();
            _note.clear();
            _choseToStop = false;
          }),
          child: const Text('Log another moment'),
        ),
      ],
    );
  }

  FirstSessionPattern _buildPayoffPattern() {
    return FirstSessionPattern(
      id: 'pressure_check_in',
      createdAt: DateTime.now(),
      title: 'A proving-loop moment',
      whyNoticed: 'You logged a moment of pressure to do more.',
      watchForText: 'whether this pressure keeps showing up',
      chips: const ['pressure', 'prove'],
      confidenceLabel: FirstSessionConfidenceLabel.early,
      sourceTextPreview: '',
      matchReason: 'You logged this as a pressure moment.',
      confidenceScore: 0.6,
      categoryId: 'prove_enough',
      category: FirstSessionPatternCategory.responsibility,
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PressureCheckInOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration:
            VoiceMemoryCards.flat(
              background: selected ? AppColors.accentLight : null,
            ).copyWith(
              border: Border.all(
                color: selected
                    ? AppColors.accentPrimary
                    : AppColors.borderSubtle,
                width: selected ? 2 : 1,
              ),
            ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? AppColors.accentPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                option.label,
                style: ArchiveMobileTypography.body(context).copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
