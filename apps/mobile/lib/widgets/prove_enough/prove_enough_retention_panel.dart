import 'dart:async';

import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_engine.dart';
import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_model.dart';
import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_store.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_post_record_model.dart';
import 'package:archiveme_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_coordinator.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/prove_enough/contradiction_capture_card.dart';
import 'package:archiveme_mobile/widgets/prove_enough/next_evidence_mission_card.dart';
import 'package:flutter/material.dart';

/// Mission + contradiction cards for prove_enough retention surfaces.
class ProveEnoughRetentionPanel extends StatefulWidget {
  const ProveEnoughRetentionPanel({
    super.key,
    this.postRecordModel,
    this.mission,
    this.entryId,
    this.journeyId,
  });

  final ProveEnoughPostRecordModel? postRecordModel;
  final NextEvidenceMissionModel? mission;
  final String? entryId;
  final String? journeyId;

  @override
  State<ProveEnoughRetentionPanel> createState() =>
      _ProveEnoughRetentionPanelState();
}

class _ProveEnoughRetentionPanelState extends State<ProveEnoughRetentionPanel> {
  static const _missionEngine = NextEvidenceMissionEngine();

  NextEvidenceMissionModel? _mission;
  String? _journeyId;
  bool _loading = true;
  var _missionMetricsTracked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    var mission = widget.mission;
    var journeyId = widget.journeyId;

    if (widget.postRecordModel != null) {
      mission = _missionEngine.fromPostRecord(
        postRecord: widget.postRecordModel!,
      );
      if (AppServices.isInitialized) {
        await NextEvidenceMissionStore.instance().save(mission);
      }
    } else if (mission == null && AppServices.isInitialized) {
      mission = await NextEvidenceMissionStore.instance().load();
      mission ??= _missionEngine.defaultMission();
    } else {
      mission ??= _missionEngine.defaultMission();
    }

    if (AppServices.isInitialized) {
      journeyId ??= (await SignalJourneyCoordinator.loadActive())?.id;
    }

    if (!mounted) return;
    setState(() {
      _mission = mission;
      _journeyId = journeyId;
      _loading = false;
    });
    unawaited(_trackMissionShown());
  }

  Future<void> _trackMissionShown() async {
    if (_missionMetricsTracked) return;
    _missionMetricsTracked = true;
    if (!AppServices.isInitialized) return;
    await RetentionMetricsTracker.track(
      RetentionMetricsTracker.nextEvidenceMissionShown,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _mission == null) return const SizedBox.shrink();

    return Column(
      key: const Key('prove_enough_retention_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NextEvidenceMissionCard(mission: _mission!),
        const SizedBox(height: AppSpacing.sm),
        ContradictionCaptureCard(
          journeyId: _journeyId,
          entryId: widget.entryId ?? widget.postRecordModel?.entryId,
        ),
      ],
    );
  }
}