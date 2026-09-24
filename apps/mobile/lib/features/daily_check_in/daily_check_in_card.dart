import 'dart:convert';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_models.dart';
import 'package:archiveme_mobile/features/daily_check_in/check_in_belief_correlation.dart';
import 'package:archiveme_mobile/features/daily_check_in/daily_check_in_store.dart';
import 'package:archiveme_mobile/models/daily_check_in.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Compact mood, energy, and habit row that sits under the writing canvas.
class DailyCheckInCard extends StatefulWidget {
  const DailyCheckInCard({
    this.now,
    this.beliefDeltas,
    super.key,
  });

  /// Clock used for today's date. Tests pass a fixed value.
  final DateTime Function()? now;

  /// When set, the card uses these deltas instead of loading local history.
  final List<BeliefChangeDelta>? beliefDeltas;

  @override
  State<DailyCheckInCard> createState() => _DailyCheckInCardState();
}

class _DailyCheckInCardState extends State<DailyCheckInCard> {
  static const _habits = ['walk', 'sleep', 'focus', 'outside'];

  int _mood = 3;
  int _energy = 3;
  final Set<String> _selected = {};
  final List<DailyCheckIn> _history = [];
  bool _saving = false;
  String? _insight;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final now = widget.now?.call() ?? DateTime.now();
    final local = now.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final checkIn = DailyCheckIn(
      id: generateUlid(now),
      dateString: '${local.year}-$month-$day',
      moodScore: _mood,
      energyLevel: _energy,
      habitsJson: jsonEncode(_selected.toList()..sort()),
    );
    final history = [
      for (final row in _history)
        if (row.dateString != checkIn.dateString) row,
      checkIn,
    ];
    try {
      var comparable = history;
      if (AppServices.isInitialized) {
        final database = AppServices.instance.sqliteDatabase.database;
        await const DailyCheckInStore().save(database, checkIn);
        comparable = await const DailyCheckInStore().loadAll(database);
      }
      final insights = await CheckInBeliefCorrelationAnalyzer.analyze(
        checkIns: comparable,
        deltas: widget.beliefDeltas ?? await _loadDeltas(),
      );
      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(comparable);
        _insight = insights.isEmpty ? null : insights.first.summary;
        _saving = false;
      });
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Daily check-in could not be saved',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<BeliefChangeDelta>> _loadDeltas() async {
    if (!AppServices.isInitialized) return const [];
    try {
      final state = await AppServices.instance.beliefEvolution.loadState();
      return CheckInBeliefCorrelationAnalyzer.deltasFromConfidences([
        for (final BeliefVersionRecord version in state.versions)
          (recordedAt: version.recordedAt, confidence: version.confidence),
      ]);
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Daily check-in skipped local shift history',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('daily_check_in_card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Today',
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _scoreRow(
          label: 'Mood',
          value: _mood,
          onChanged: (value) => setState(() => _mood = value),
          keyPrefix: 'daily_check_in_mood',
        ),
        const SizedBox(height: 4),
        _scoreRow(
          label: 'Energy',
          value: _energy,
          onChanged: (value) => setState(() => _energy = value),
          keyPrefix: 'daily_check_in_energy',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final habit in _habits)
              FilterChip(
                key: Key('daily_check_in_habit_$habit'),
                label: Text(habit),
                selected: _selected.contains(habit),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selected.add(habit);
                    } else {
                      _selected.remove(habit);
                    }
                  });
                },
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('daily_check_in_save'),
            onPressed: _saving ? null : _save,
            child: const Text('Save check-in'),
          ),
        ),
        if (_insight != null)
          Text(
            _insight!,
            key: const Key('daily_check_in_insight'),
            style: const TextStyle(color: AppTheme.muted, height: 1.4),
          ),
      ],
    );
  }

  Widget _scoreRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required String keyPrefix,
  }) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        for (var score = 1; score <= 5; score++)
          IconButton(
            key: Key('${keyPrefix}_$score'),
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(score),
            icon: Icon(
              score <= value ? Icons.circle : Icons.circle_outlined,
              size: 16,
            ),
          ),
      ],
    );
  }
}
