import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/pro_moment_timing/pro_moment_timing_audit_v2_copy.dart';
import '../../features/pro_moment_timing/pro_moment_timing_audit_v2_engine.dart';
import '../../features/pro_moment_timing/pro_moment_timing_audit_v2_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Beta-only Pro moment timing audit — rule checks, no purchase simulation.
class ProMomentTimingAuditV2Card extends StatelessWidget {
  const ProMomentTimingAuditV2Card({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
    this.snapshotOverride,
  });

  final String source;
  final bool compact;
  final ProMomentTimingAuditV2Snapshot? snapshotOverride;

  @override
  Widget build(BuildContext context) {
    if (!ProMomentTimingAuditV2Engine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(
        key: Key('pro_moment_timing_audit_v2_hidden'),
      );
    }

    final snapshot = snapshotOverride ?? ProMomentTimingAuditV2Engine.build();

    return Container(
      key: const Key('pro_moment_timing_audit_v2_card'),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            snapshot.title,
            key: const Key('pro_moment_timing_audit_v2_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.subtitle,
            key: const Key('pro_moment_timing_audit_v2_subtitle'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${snapshot.readyCount}/${snapshot.checks.length} ready',
            key: const Key('pro_moment_timing_audit_v2_summary'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          for (final check in snapshot.checks) ...[
            _CheckRow(check: check),
            const SizedBox(height: 6),
          ],
          if (snapshot.diagnoses.isNotEmpty) ...[
            const SizedBox(height: 4),
            _DiagnosisBlock(diagnoses: snapshot.diagnoses),
          ],
          const SizedBox(height: 4),
          Text(
            ProMomentTimingAuditV2Copy.localNote,
            key: const Key('pro_moment_timing_audit_v2_note'),
            style: const TextStyle(
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

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final ProMomentTimingAuditV2Check check;

  Color _statusColor() => switch (check.status) {
        ProMomentTimingAuditV2Status.ready => AppColors.success,
        ProMomentTimingAuditV2Status.watch => AppColors.warning,
        ProMomentTimingAuditV2Status.blocked => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _statusColor(),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                check.label,
                key: Key('pro_moment_timing_audit_v2_check_${check.id.name}'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${check.status.label} · ${check.detailLabel}',
                key: Key(
                  'pro_moment_timing_audit_v2_detail_${check.id.name}',
                ),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiagnosisBlock extends StatelessWidget {
  const _DiagnosisBlock({required this.diagnoses});

  final List<ProMomentTimingAuditV2Diagnosis> diagnoses;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pro_moment_timing_audit_v2_diagnoses'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final diagnosis in diagnoses)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                diagnosis.title,
                key: Key(
                  'pro_moment_timing_audit_v2_diagnosis_${diagnosis.id.name}',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
