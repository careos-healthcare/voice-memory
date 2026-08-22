import 'dart:async';

import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/features/capture/providers/capture_module_providers.dart';
import 'package:archiveme_mobile/features/capture/storage/capture_audio_metadata_store.dart';
import 'package:archiveme_mobile/features/llm/application/llm_capture_analysis_service.dart';
import 'package:archiveme_mobile/features/llm/domain/llm_feed_card_state.dart';
import 'package:archiveme_mobile/features/llm/worker/llm_background_worker.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_knowledge_graph_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final llmBackgroundWorkerProvider = Provider<LlmBackgroundWorker>(
  (ref) => LlmBackgroundWorker(),
);

final llmCaptureAnalysisServiceProvider = Provider<LlmCaptureAnalysisService?>(
  (ref) {
    final config = ref.watch(captureModuleRuntimeConfigProvider);
    if (config == null) return null;

    final metadataStore = CaptureAudioMetadataStore(
      sqliteFilePath: config.sqliteFilePath,
      encryptionPassword: config.encryptionPassword,
      keyAlias: config.keyAlias,
    );

    final sqlite = ref.watch(appSqliteDatabaseProvider);
    return LlmCaptureAnalysisService(
      metadataStore: metadataStore,
      worker: ref.watch(llmBackgroundWorkerProvider),
      graphRepository: ReflectionKnowledgeGraphRepository(sqlite.database),
      resolveLocalLlm: AppServices.instance.resolveLocalLlm,
      resourceGuard: ResourceGuard.shared,
    );
  },
);

final llmFeedStatesProvider =
    Provider<ValueNotifier<Map<String, LlmFeedCardState>>?>((ref) {
      final service = ref.watch(llmCaptureAnalysisServiceProvider);
      return service?.feedStates;
    });

final llmAnalysisBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(llmCaptureAnalysisServiceProvider);
  if (service == null) return;
  unawaited(service.refreshPendingCaptures());
});

class LlmAnalysisBootstrap extends ConsumerWidget {
  const LlmAnalysisBootstrap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(llmAnalysisBootstrapProvider);
    return child;
  }
}
