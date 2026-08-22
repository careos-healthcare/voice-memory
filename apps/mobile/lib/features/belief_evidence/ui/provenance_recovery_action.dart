import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/belief_evidence/provenance_recovery/provenance_recovery_port.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_palette.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_copy.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// A user-initiated offer to recover an entry's transcript origin by reading
/// its saved recording again.
///
/// Nothing here starts work. Building the widget reads the consent decision
/// and probes for the audio file, both local; the injected
/// [ProvenanceRecoveryPort] is reached only from the confirm button inside the
/// disclosure sheet, which is itself reached only from a tap. Automatic
/// triggering was rejected outright: a misfire would put a back catalogue of
/// personal recordings in front of a third party that nobody asked to involve.
///
/// Where a gate is closed the button stays and the sheet explains what would
/// have to change. A silently disabled control teaches a user nothing and
/// looks like a bug.
class ProvenanceRecoveryAction extends StatefulWidget {
  const ProvenanceRecoveryAction({
    required this.entryIds,
    required this.planner,
    super.key,
    this.port = const UnwiredProvenanceRecoveryPort(),
    this.onDeviceSettingName = OnDeviceProcessingCopy.title,
  });

  final List<String> entryIds;
  final ProvenanceRecoveryPlanner planner;
  final ProvenanceRecoveryPort port;

  /// Label of the switch that vetoes remote work, quoted back to the user so
  /// they can find the row it names.
  final String onDeviceSettingName;

  static const Key actionKey = Key('provenance_recovery_action');
  static const Key sheetKey = Key('provenance_recovery_sheet');
  static const Key confirmKey = Key('provenance_recovery_confirm');
  static const Key cancelKey = Key('provenance_recovery_cancel');
  static const Key blockedKey = Key('provenance_recovery_blocked');
  static const Key audioMissingKey = Key('provenance_recovery_audio_missing');
  static const Key outcomeKey = Key('provenance_recovery_outcome');

  @override
  State<ProvenanceRecoveryAction> createState() =>
      _ProvenanceRecoveryActionState();
}

class _ProvenanceRecoveryActionState extends State<ProvenanceRecoveryAction> {
  late Future<ProvenanceRecoveryPlan> _plan = widget.planner.planFor(
    widget.entryIds,
  );
  String? _outcome;

  @override
  void didUpdateWidget(ProvenanceRecoveryAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entryIds, widget.entryIds)) {
      _plan = widget.planner.planFor(widget.entryIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProvenanceRecoveryPlan>(
      future: _plan,
      builder: (context, snapshot) {
        final plan = snapshot.data;
        if (plan == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.hasRecoverableAudio)
              _buildButton(context, plan)
            else
              _buildAudioMissing(context, plan),
            if (_outcome != null) ...[
              const SizedBox(height: 4),
              Text(
                _outcome!,
                key: ProvenanceRecoveryAction.outcomeKey,
                style: _helperStyle(context),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, ProvenanceRecoveryPlan plan) {
    final palette = EvidenceCitationPalette.of(context);
    return Semantics(
      button: true,
      label: ProvenanceRecoveryCopy.actionSemantics(
        plan.recoverableEntryIds.length,
      ),
      excludeSemantics: true,
      child: TextButton(
        key: ProvenanceRecoveryAction.actionKey,
        onPressed: () => _openSheet(plan),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: palette.quoteAccent,
        ),
        child: const Text(ProvenanceRecoveryCopy.actionLabel),
      ),
    );
  }

  Widget _buildAudioMissing(
    BuildContext context,
    ProvenanceRecoveryPlan plan,
  ) {
    return Text(
      plan.isBulk
          ? ProvenanceRecoveryCopy.audioMissingBulk
          : ProvenanceRecoveryCopy.audioMissing,
      key: ProvenanceRecoveryAction.audioMissingKey,
      style: _helperStyle(context),
    );
  }

  TextStyle _helperStyle(BuildContext context) =>
      ArchiveMobileTypography.responsiveHelper(
        context,
        color: EvidenceCitationPalette.of(context).unverifiedBody,
      );

  Future<void> _openSheet(ProvenanceRecoveryPlan plan) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _RecoveryDisclosureSheet(
        plan: plan,
        onDeviceSettingName: widget.onDeviceSettingName,
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _run(plan);
  }

  Future<void> _run(ProvenanceRecoveryPlan plan) async {
    final outcome = await widget.port.recover(plan.recoverableEntryIds);
    if (!mounted) return;
    setState(() {
      _outcome = outcome.recoveredAny
          ? ProvenanceRecoveryCopy.outcomeRecovered(
              recovered: outcome.recoveredCount,
              requested: outcome.requestedCount,
            )
          : ProvenanceRecoveryCopy.outcomeNoneRecovered;
      _plan = widget.planner.planFor(widget.entryIds);
    });
  }
}

/// Everything the recovery would do, stated before it can be started.
///
/// The confirm button exists only when the plan can actually run, so a user is
/// never one tap from an attempt that the gates would refuse anyway. When it
/// cannot run, its place is taken by the specific change that would unblock
/// it.
class _RecoveryDisclosureSheet extends StatelessWidget {
  const _RecoveryDisclosureSheet({
    required this.plan,
    required this.onDeviceSettingName,
  });

  final ProvenanceRecoveryPlan plan;
  final String onDeviceSettingName;

  @override
  Widget build(BuildContext context) {
    final palette = EvidenceCitationPalette.of(context);
    final titleStyle = ArchiveMobileTypography.cardLabel(
      context,
      color: palette.unverifiedTitle,
    ).copyWith(fontWeight: FontWeight.w700);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
      color: palette.unverifiedBody,
    );

    return SafeArea(
      key: ProvenanceRecoveryAction.sheetKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ProvenanceRecoveryCopy.sheetTitle, style: titleStyle),
            const SizedBox(height: AppSpacing.xs),
            Text(_scopeLine, style: bodyStyle),
            const SizedBox(height: AppSpacing.xs),
            Text(ProvenanceRecoveryCopy.whatItDoes, style: bodyStyle),
            if (plan.needsRemoteProcessing) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(ProvenanceRecoveryCopy.remoteDisclosure, style: bodyStyle),
              const SizedBox(height: AppSpacing.xs),
              Text(ProvenanceRecoveryCopy.consentReminder, style: bodyStyle),
            ],
            if (!plan.consentSatisfied) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(ProvenanceRecoveryCopy.blockedHeading, style: titleStyle),
              const SizedBox(height: 2),
              Text(
                _blockerExplanation,
                key: ProvenanceRecoveryAction.blockedKey,
                style: bodyStyle,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (plan.canRun)
                  FilledButton(
                    key: ProvenanceRecoveryAction.confirmKey,
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(ProvenanceRecoveryCopy.confirmLabel),
                  ),
                TextButton(
                  key: ProvenanceRecoveryAction.cancelKey,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(ProvenanceRecoveryCopy.cancelLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _scopeLine {
    final total = plan.entryIds.length;
    final withAudio = plan.recoverableEntryIds.length;
    if (withAudio == total) return ProvenanceRecoveryCopy.scopeFor(total);
    return ProvenanceRecoveryCopy.partialScopeFor(
      withAudio: withAudio,
      total: total,
    );
  }

  String get _blockerExplanation => switch (plan.blocker) {
    ProvenanceRecoveryBlocker.onDeviceOnly =>
      ProvenanceRecoveryCopy.onDeviceOnlyBlocker(onDeviceSettingName),
    ProvenanceRecoveryBlocker.transcriptionNotPermitted =>
      ProvenanceRecoveryCopy.transcriptionNotPermittedBlocker,
    ProvenanceRecoveryBlocker.onDeviceOnlyAndNotPermitted =>
      ProvenanceRecoveryCopy.bothBlockers(onDeviceSettingName),
    ProvenanceRecoveryBlocker.audioMissing => plan.isBulk
        ? ProvenanceRecoveryCopy.audioMissingBulk
        : ProvenanceRecoveryCopy.audioMissing,
    null => '',
  };
}
