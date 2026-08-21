import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_conversion_diagnosis/beta_conversion_diagnosis_copy.dart';
import 'package:archiveme_mobile/features/beta_conversion_diagnosis/beta_conversion_diagnosis_engine.dart';
import 'package:archiveme_mobile/features/beta_conversion_diagnosis/beta_conversion_diagnosis_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Beta-only conversion diagnosis card — metadata counts only.
class BetaConversionDiagnosisCard extends StatefulWidget {
  const BetaConversionDiagnosisCard({
    super.key,
    this.source = 'settings',
    this.compact = false,
    this.resultOverride,
  });

  final String source;
  final bool compact;
  final BetaConversionDiagnosisResult? resultOverride;

  @override
  State<BetaConversionDiagnosisCard> createState() =>
      _BetaConversionDiagnosisCardState();
}

class _BetaConversionDiagnosisCardState
    extends State<BetaConversionDiagnosisCard> {
  BetaConversionDiagnosisResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.resultOverride != null) {
      _result = widget.resultOverride;
      return;
    }
    unawaited(_loadResult());
  }

  Future<void> _loadResult() async {
    final result = await BetaConversionDiagnosisEngine.build();
    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    if (!BetaConversionDiagnosisEngine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(
        key: Key('beta_conversion_diagnosis_hidden'),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink(
        key: Key('beta_conversion_diagnosis_loading'),
      );
    }

    return Container(
      key: const Key('beta_conversion_diagnosis_card'),
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
            result.title,
            key: const Key('beta_conversion_diagnosis_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            result.body,
            key: const Key('beta_conversion_diagnosis_body'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (!result.hasDiagnoses)
            const Text(
              BetaConversionDiagnosisCopy.noIssuesLine,
              key: Key('beta_conversion_diagnosis_no_issues'),
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                height: 1.4,
              ),
            )
          else ...[
            Text(
              BetaConversionDiagnosisCopy.diagnosisTitle,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final diagnosis in result.diagnoses) ...[
              _DiagnosisTile(diagnosis: diagnosis),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 4),
          const Text(
            BetaConversionDiagnosisCopy.localCountsNote,
            key: Key('beta_conversion_diagnosis_note'),
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisTile extends StatelessWidget {
  const _DiagnosisTile({required this.diagnosis});

  final BetaConversionDiagnosisItem diagnosis;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('beta_conversion_diagnosis_item_${diagnosis.metricId.name}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diagnosis.message,
            key: Key(
              'beta_conversion_diagnosis_message_${diagnosis.metricId.name}',
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${BetaConversionDiagnosisCopy.metricPrefix}: '
            '${diagnosis.metricLabel} · ${diagnosis.currentValueLabel}',
            key: Key(
              'beta_conversion_diagnosis_metric_${diagnosis.metricId.name}',
            ),
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          Text(
            '${BetaConversionDiagnosisCopy.targetPrefix}: '
            '${diagnosis.targetValueLabel}',
            key: Key(
              'beta_conversion_diagnosis_target_${diagnosis.metricId.name}',
            ),
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          Text(
            '${BetaConversionDiagnosisCopy.fixPrefix}: '
            '${diagnosis.recommendedFixLabel}',
            key: Key(
              'beta_conversion_diagnosis_fix_${diagnosis.metricId.name}',
            ),
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}