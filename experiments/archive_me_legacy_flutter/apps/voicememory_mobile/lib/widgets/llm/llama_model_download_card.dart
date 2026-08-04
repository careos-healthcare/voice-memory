import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/llama_model_state.dart';
import '../../services/app_services_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'llama_model_download_copy.dart';

enum LlamaModelDownloadStatus {
  notConfigured,
  optInRequired,
  notInstalled,
  checkingStorage,
  waitingForWifi,
  downloading,
  userPaused,
  verifying,
  ready,
  failed,
}

@immutable
final class LlamaModelDownloadState {
  const LlamaModelDownloadState({
    required this.status,
    this.progress = 0,
    this.failureDetail,
  });

  const LlamaModelDownloadState.notConfigured()
    : this(status: LlamaModelDownloadStatus.notConfigured);

  final LlamaModelDownloadStatus status;
  final double progress;
  final String? failureDetail;
}

abstract interface class LlamaModelDownloadController {
  LlamaModelDownloadState get state;
  Stream<LlamaModelDownloadState> get states;

  Future<void> download();
  Future<void> pause();
  Future<void> resume();
  Future<void> retry();
  Future<void> remove();
}

/// Bridges immutable production state without coupling the UI to a provider.
///
/// A future Riverpod provider can return this adapter from
/// [LlamaModelControllerProviderAdapter] without changing the card or screens.
final class LlamaModelStateController implements LlamaModelDownloadController {
  const LlamaModelStateController({
    required this.readProductionState,
    required this.productionStates,
    required this.downloadAction,
    required this.pauseAction,
    required this.resumeAction,
    required this.retryAction,
    required this.removeAction,
  });

  final LlamaModelState Function() readProductionState;
  final Stream<LlamaModelState> productionStates;
  final Future<void> Function() downloadAction;
  final Future<void> Function() pauseAction;
  final Future<void> Function() resumeAction;
  final Future<void> Function() retryAction;
  final Future<void> Function() removeAction;

  @override
  LlamaModelDownloadState get state => _fromState(readProductionState());

  @override
  Stream<LlamaModelDownloadState> get states =>
      productionStates.map(_fromState);

  @override
  Future<void> download() => downloadAction();

  @override
  Future<void> pause() => pauseAction();

  @override
  Future<void> resume() => resumeAction();

  @override
  Future<void> retry() => retryAction();

  @override
  Future<void> remove() => removeAction();

  static LlamaModelDownloadState _fromState(LlamaModelState state) {
    final status = switch (state.status) {
      LlamaModelStatus.notConfigured => LlamaModelDownloadStatus.notConfigured,
      LlamaModelStatus.notOptedIn => LlamaModelDownloadStatus.optInRequired,
      LlamaModelStatus.checkingStorage =>
        LlamaModelDownloadStatus.checkingStorage,
      LlamaModelStatus.waitingForWifi =>
        LlamaModelDownloadStatus.waitingForWifi,
      LlamaModelStatus.queued ||
      LlamaModelStatus.downloading => LlamaModelDownloadStatus.downloading,
      LlamaModelStatus.paused => LlamaModelDownloadStatus.userPaused,
      LlamaModelStatus.verifying => LlamaModelDownloadStatus.verifying,
      LlamaModelStatus.installed => LlamaModelDownloadStatus.ready,
      LlamaModelStatus.insufficientStorage ||
      LlamaModelStatus.failed => LlamaModelDownloadStatus.failed,
    };
    return LlamaModelDownloadState(
      status: status,
      progress: state.progress,
      failureDetail: state.failure?.name,
    );
  }
}

typedef LlamaModelControllerProviderAdapter =
    LlamaModelDownloadController? Function(WidgetRef ref);

LlamaModelDownloadController? productionLlamaModelController(WidgetRef ref) {
  final manager = ref.watch(llamaModelManagerProvider);
  if (manager == null) return null;
  final actions = ref.watch(llamaModelActionsProvider);
  return LlamaModelStateController(
    readProductionState: () => manager.state,
    productionStates: manager.states,
    downloadAction: actions.optIn,
    pauseAction: actions.pause,
    resumeAction: actions.resume,
    retryAction: actions.resume,
    removeAction: actions.remove,
  );
}

class LlamaModelDownloadCard extends StatelessWidget {
  const LlamaModelDownloadCard({
    super.key,
    this.controller,
    this.providerAdapter,
    this.source = 'unspecified',
  }) : assert(controller == null || providerAdapter == null),
       assert(source != '');

  final LlamaModelDownloadController? controller;

  /// Optional card-local Riverpod bridge for the production provider.
  ///
  /// Only this card rebuilds when the adapter watches provider state.
  final LlamaModelControllerProviderAdapter? providerAdapter;

  /// Stable origin identifier for tests and future source analytics.
  final String source;

  @override
  Widget build(BuildContext context) {
    final adapter =
        providerAdapter ??
        (controller == null ? productionLlamaModelController : null);
    return KeyedSubtree(
      key: Key('llama_model_download_source_$source'),
      child: adapter != null
          ? _ProviderBackedCard(providerAdapter: adapter)
          : _ControllerCard(controller: controller),
    );
  }
}

class _ProviderBackedCard extends ConsumerWidget {
  const _ProviderBackedCard({required this.providerAdapter});

  final LlamaModelControllerProviderAdapter providerAdapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _ControllerCard(controller: providerAdapter(ref));
}

class _ControllerCard extends StatefulWidget {
  const _ControllerCard({this.controller});

  final LlamaModelDownloadController? controller;

  @override
  State<_ControllerCard> createState() => _ControllerCardState();
}

class _ControllerCardState extends State<_ControllerCard> {
  StreamSubscription<LlamaModelDownloadState>? _subscription;
  late LlamaModelDownloadState _state;
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(_ControllerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) _connect();
  }

  void _connect() {
    unawaited(_subscription?.cancel());
    final controller = widget.controller;
    _state = controller?.state ?? const LlamaModelDownloadState.notConfigured();
    _subscription = controller?.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(_state);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Card(
        key: const Key('llama_model_download_card'),
        color: AppColors.backgroundSecondary,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(
                  LlamaModelDownloadCopy.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                LlamaModelDownloadCopy.description,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                key: const Key('llama_model_download_status'),
                container: true,
                liveRegion: true,
                label: 'Model download status. ${presentation.statusText}',
                child: ExcludeSemantics(
                  child: Text(
                    presentation.statusText,
                    style: TextStyle(
                      color: _state.status == LlamaModelDownloadStatus.failed
                          ? AppColors.error
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (presentation.showProgress) ...[
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  key: const Key('llama_model_download_progress'),
                  container: true,
                  label: 'Model download progress',
                  value: '${(_state.progress.clamp(0.0, 1.0) * 100).round()}%',
                  child: ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: _state.progress.clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ],
              if (_state.status == LlamaModelDownloadStatus.failed &&
                  _state.failureDetail != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _state.failureDetail!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if (presentation.action != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    key: const Key('llama_model_download_action'),
                    container: true,
                    button: true,
                    enabled: !_actionInFlight,
                    label: presentation.actionLabel,
                    onTap: _actionInFlight
                        ? null
                        : () => _run(presentation.action!),
                    child: ExcludeSemantics(
                      child: FilledButton(
                        onPressed: _actionInFlight
                            ? null
                            : () => _run(presentation.action!),
                        child: Text(presentation.actionLabel!),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              const Text(
                LlamaModelDownloadCopy.attribution,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _LlamaModelPresentation _presentationFor(LlamaModelDownloadState state) {
    final controller = widget.controller;
    return switch (state.status) {
      LlamaModelDownloadStatus.notConfigured => const _LlamaModelPresentation(
        statusText: LlamaModelDownloadCopy.notConfigured,
      ),
      LlamaModelDownloadStatus.optInRequired ||
      LlamaModelDownloadStatus.notInstalled => _LlamaModelPresentation(
        statusText: LlamaModelDownloadCopy.optInRequired,
        actionLabel: 'Download',
        action: controller?.download,
      ),
      LlamaModelDownloadStatus.checkingStorage => const _LlamaModelPresentation(
        statusText: LlamaModelDownloadCopy.checkingStorage,
      ),
      LlamaModelDownloadStatus.waitingForWifi => _LlamaModelPresentation(
        statusText: LlamaModelDownloadCopy.waitingForWifi,
        actionLabel: 'Pause',
        action: controller?.pause,
      ),
      LlamaModelDownloadStatus.downloading => _LlamaModelPresentation(
        statusText: LlamaModelDownloadCopy.downloading(
          (state.progress.clamp(0.0, 1.0) * 100).round(),
        ),
        showProgress: true,
        actionLabel: 'Pause',
        action: controller?.pause,
      ),
      LlamaModelDownloadStatus.userPaused => _LlamaModelPresentation(
        statusText: LlamaModelDownloadCopy.userPaused,
        actionLabel: 'Resume',
        action: controller?.resume,
      ),
      LlamaModelDownloadStatus.verifying => const _LlamaModelPresentation(
        statusText: LlamaModelDownloadCopy.verifying,
      ),
      LlamaModelDownloadStatus.ready => _LlamaModelPresentation(
        statusText: LlamaModelDownloadCopy.ready,
        actionLabel: 'Remove',
        action: controller?.remove,
      ),
      LlamaModelDownloadStatus.failed => _LlamaModelPresentation(
        statusText: LlamaModelDownloadCopy.failed,
        actionLabel: 'Retry',
        action: controller?.retry,
      ),
    };
  }
}

final class _LlamaModelPresentation {
  const _LlamaModelPresentation({
    required this.statusText,
    this.showProgress = false,
    this.actionLabel,
    this.action,
  });

  final String statusText;
  final bool showProgress;
  final String? actionLabel;
  final Future<void> Function()? action;
}
