import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/beta_decision/beta_decision_copy.dart';
import '../../features/beta_decision/beta_decision_model.dart';
import '../../features/beta_decision/beta_tester_outcome_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Beta-only tester outcome logger — local metadata, no consumer behaviour changes.
class BetaTesterOutcomeLogCard extends StatefulWidget {
  const BetaTesterOutcomeLogCard({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
    this.onChanged,
    this.store,
  });

  final String source;
  final bool compact;
  final VoidCallback? onChanged;
  final BetaTesterOutcomeStore? store;

  @override
  State<BetaTesterOutcomeLogCard> createState() =>
      _BetaTesterOutcomeLogCardState();
}

class _BetaTesterOutcomeLogCardState extends State<BetaTesterOutcomeLogCard> {
  final _testerIdController = TextEditingController();
  final _notesController = TextEditingController();
  final _selectedSignals = <BetaDecisionSignal>{};
  var _loaded = false;
  var _errorText = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _testerIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await BetaTesterOutcomeStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      if (_testerIdController.text.trim().isEmpty) {
        _testerIdController.text = BetaTesterOutcomeStore.suggestNextTesterId();
      }
    });
  }

  Future<void> _saveOutcome() async {
    if (_selectedSignals.isEmpty) {
      setState(() => _errorText = BetaDecisionCopy.outcomeNoSignalsSelected);
      return;
    }
    final testerId = _testerIdController.text.trim().isEmpty
        ? BetaTesterOutcomeStore.suggestNextTesterId()
        : _testerIdController.text.trim();
    final notes = _notesController.text.trim();
    final store = widget.store ?? BetaTesterOutcomeStore.instance();
    await store.addOutcome(
      BetaTesterOutcome(
        testerId: testerId,
        signals: Set<BetaDecisionSignal>.from(_selectedSignals),
        notes: notes.isEmpty ? null : notes,
      ),
    );
    if (!mounted) return;
    setState(() {
      _selectedSignals.clear();
      _notesController.clear();
      _testerIdController.text = BetaTesterOutcomeStore.suggestNextTesterId();
      _errorText = '';
    });
    widget.onChanged?.call();
  }

  Future<void> _removeAt(int index) async {
    final store = widget.store ?? BetaTesterOutcomeStore.instance();
    await store.removeAt(index);
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call();
  }

  Future<void> _clearAll() async {
    final store = widget.store ?? BetaTesterOutcomeStore.instance();
    await store.clearAll();
    if (!mounted) return;
    setState(() {
      _testerIdController.text = BetaTesterOutcomeStore.suggestNextTesterId();
    });
    widget.onChanged?.call();
  }

  void _toggleSignal(BetaDecisionSignal signal, bool selected) {
    setState(() {
      if (selected) {
        _selectedSignals.add(signal);
      } else {
        _selectedSignals.remove(signal);
      }
      _errorText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ArchiveBetaMissionGate.isEnabled) {
      return const SizedBox.shrink(
        key: Key('beta_tester_outcome_log_card_hidden'),
      );
    }
    if (!_loaded) {
      return const SizedBox.shrink(
        key: Key('beta_tester_outcome_log_card_loading'),
      );
    }

    final outcomes = BetaTesterOutcomeStore.allOutcomes;

    return Container(
      key: const Key('beta_tester_outcome_log_card'),
      padding: EdgeInsets.all(widget.compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            BetaDecisionCopy.outcomeLogTitle,
            key: const Key('beta_tester_outcome_log_heading'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            BetaDecisionCopy.outcomeLogSubtitle,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('beta_tester_outcome_tester_id'),
            controller: _testerIdController,
            decoration: const InputDecoration(
              labelText: BetaDecisionCopy.outcomeTesterIdLabel,
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          for (final group in BetaDecisionCopy.signalGroups.entries) ...[
            Text(
              group.key,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final signal in group.value)
                  FilterChip(
                    key: Key('beta_tester_outcome_signal_${signal.name}'),
                    label: Text(BetaDecisionCopy.signalLabel(signal)),
                    selected: _selectedSignals.contains(signal),
                    onSelected: (selected) => _toggleSignal(signal, selected),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            key: const Key('beta_tester_outcome_notes'),
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: BetaDecisionCopy.outcomeNotesLabel,
              isDense: true,
            ),
            maxLines: 2,
          ),
          if (_errorText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _errorText,
              key: const Key('beta_tester_outcome_error'),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton(
            key: const Key('beta_tester_outcome_save'),
            onPressed: () => unawaited(_saveOutcome()),
            child: const Text(BetaDecisionCopy.outcomeSaveCta),
          ),
          const SizedBox(height: 12),
          Text(
            '${BetaDecisionCopy.outcomeLoggedCount}: ${outcomes.length}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < outcomes.length; i++)
            ListTile(
              key: Key('beta_tester_outcome_logged_${outcomes[i].testerId}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                outcomes[i].testerId,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                outcomes[i].signals
                    .map(BetaDecisionCopy.signalLabel)
                    .join(' · '),
                style: const TextStyle(fontSize: 12, height: 1.3),
              ),
              trailing: IconButton(
                key: Key('beta_tester_outcome_delete_$i'),
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => unawaited(_removeAt(i)),
              ),
            ),
          if (outcomes.isNotEmpty)
            TextButton(
              key: const Key('beta_tester_outcome_clear'),
              onPressed: () => unawaited(_clearAll()),
              child: const Text(BetaDecisionCopy.outcomeClearCta),
            ),
        ],
      ),
    );
  }
}
