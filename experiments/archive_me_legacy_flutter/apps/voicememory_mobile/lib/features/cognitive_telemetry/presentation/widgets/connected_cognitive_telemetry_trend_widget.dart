import 'package:flutter/material.dart';

import '../../../../services/app_services.dart';
import '../../infrastructure/cognitive_metrics_history_store.dart';
import 'clinical_telemetry_trend_widget.dart';

/// Binds [ClinicalTelemetryTrendWidget] to the rolling cognitive metrics store.
class ConnectedCognitiveTelemetryTrendWidget extends StatelessWidget {
  const ConnectedCognitiveTelemetryTrendWidget({super.key, this.store});

  final CognitiveMetricsHistoryStore? store;

  @override
  Widget build(BuildContext context) {
    final resolvedStore =
        store ?? AppServices.instance.cognitiveMetricsHistoryStore;

    return ListenableBuilder(
      listenable: resolvedStore,
      builder: (context, _) {
        return ClinicalTelemetryTrendWidget(
          key: const Key('cognitive_speech_baseline_trend'),
          metricsHistory: resolvedStore.metricsHistory,
        );
      },
    );
  }
}
