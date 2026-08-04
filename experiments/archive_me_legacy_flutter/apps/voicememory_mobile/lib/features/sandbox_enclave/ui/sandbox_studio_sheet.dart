import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../sandbox_enclave_service.dart';
import '../sandbox_models.dart';

typedef SandboxStudioRunner =
    Future<SandboxExecutionResult> Function(
      String moduleId,
      SandboxDataGrant grant,
    );

final class SandboxStudioSheet extends StatefulWidget {
  const SandboxStudioSheet({
    super.key,
    required this.service,
    this.runOverride,
    this.initialSnapshot,
  });

  final SandboxEnclaveService service;
  final SandboxStudioRunner? runOverride;
  final SandboxEnclaveSnapshot? initialSnapshot;

  static Future<void> show(
    BuildContext context, {
    required SandboxEnclaveService service,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'sandbox-studio',
    builder: (_) => SandboxStudioSheet(service: service),
  );

  @override
  State<SandboxStudioSheet> createState() => _SandboxStudioSheetState();
}

class _SandboxStudioSheetState extends State<SandboxStudioSheet> {
  late SandboxEnclaveSnapshot _snapshot;
  StreamSubscription<SandboxEnclaveSnapshot>? _subscription;
  String? _moduleId;
  SandboxDataGrant? _grant;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot ?? widget.service.current;
    final manifests = widget.service.manager.registry.manifests;
    if (manifests.isNotEmpty) {
      _moduleId = manifests.first.id;
      _grant = manifests.first.dataGrants.firstOrNull;
    }
    _subscription = widget.service.changes.listen((value) {
      if (mounted) setState(() => _snapshot = value);
    });
  }

  SandboxRuntimeCapability? get _wasmtime => _snapshot.capabilities
      .where((item) => item.kind == SandboxRuntimeKind.wasmtime)
      .firstOrNull;

  Future<void> _run() async {
    final moduleId = _moduleId;
    final grant = _grant;
    if (moduleId == null || grant == null) return;
    final override = widget.runOverride;
    if (override != null) {
      setState(() {
        _snapshot = SandboxEnclaveSnapshot(
          capabilities: _snapshot.capabilities,
          running: true,
          audits: _snapshot.audits,
          latest: _snapshot.latest,
        );
      });
      final result = await override(moduleId, grant);
      if (!mounted) return;
      setState(() {
        _snapshot = SandboxEnclaveSnapshot(
          capabilities: _snapshot.capabilities,
          running: false,
          audits: _snapshot.audits,
          latest: result,
        );
      });
      return;
    }
    await widget.service.run(
      moduleId: moduleId,
      dataRequest: grant == SandboxDataGrant.cognitiveMetrics
          ? const SandboxDataViewRequest.cognitiveMetrics()
          : const SandboxDataViewRequest.graphNodes(nodeIds: []),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manifests = widget.service.manager.registry.manifests;
    final selected = manifests
        .where((item) => item.id == _moduleId)
        .firstOrNull;
    final capability = _wasmtime;
    return SafeArea(
      top: false,
      child: Column(
        key: const Key('sandbox-studio-sheet'),
        children: [
          ListTile(
            title: const Text(
              'Wasm Sandbox Enclave',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'No network • no filesystem • explicit copied data only',
            ),
            trailing: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _CapabilityCard(capabilities: _snapshot.capabilities),
                const SizedBox(height: 12),
                Text(
                  'Trusted module',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                DropdownButtonFormField<String>(
                  key: const Key('sandbox-module-picker'),
                  initialValue: _moduleId,
                  decoration: const InputDecoration(
                    labelText: 'Bundled, hash-pinned module',
                  ),
                  items: [
                    for (final manifest in manifests)
                      DropdownMenuItem(
                        value: manifest.id,
                        child: Text(manifest.displayName),
                      ),
                  ],
                  onChanged: _snapshot.running
                      ? null
                      : (value) {
                          setState(() {
                            _moduleId = value;
                            _grant = manifests
                                .where((item) => item.id == value)
                                .firstOrNull
                                ?.dataGrants
                                .firstOrNull;
                          });
                        },
                ),
                if (selected != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    key: const Key('sandbox-manifest-inspector'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        'v${selected.version} • ${selected.entrypoint}\n'
                        'SHA-256 ${selected.sha256}\n'
                        'Imports: ${selected.allowedImports.isEmpty ? 'none' : selected.allowedImports.join(', ')}\n'
                        'Memory: ${selected.budget.maximumMemoryBytes} bytes • '
                        'Fuel: ${selected.budget.maximumFuel}',
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final grant in selected.dataGrants)
                        ChoiceChip(
                          key: Key('sandbox-grant-${grant.name}'),
                          label: Text(grant.name),
                          selected: grant == _grant,
                          onSelected: _snapshot.running
                              ? null
                              : (_) => setState(() => _grant = grant),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Script console',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Python and JavaScript source execution unavailable',
                          key: Key('sandbox-source-unavailable'),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Only audited, bundled WebAssembly modules may run. '
                          'Pyodide and JavaScript remain capability-gated until '
                          'their isolated runtimes are packaged.',
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('sandbox-run'),
                        onPressed:
                            capability?.available == true &&
                                !_snapshot.running &&
                                _moduleId != null &&
                                _grant != null
                            ? _run
                            : null,
                        icon: _snapshot.running
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: const Text('Run isolated module'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const Key('sandbox-cancel'),
                      onPressed: _snapshot.running
                          ? widget.service.cancel
                          : null,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ResourceMeter(result: _snapshot.latest),
                const SizedBox(height: 12),
                _ConsoleOutput(result: _snapshot.latest),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capabilities});

  final List<SandboxRuntimeCapability> capabilities;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('sandbox-capabilities'),
    child: Column(
      children: [
        for (final capability in capabilities)
          ListTile(
            dense: true,
            leading: Icon(
              capability.available ? Icons.verified_user : Icons.lock_outline,
            ),
            title: Text(capability.kind.name),
            subtitle: Text(
              capability.available ? capability.backend : capability.reason,
            ),
          ),
      ],
    ),
  );
}

final class _ResourceMeter extends StatelessWidget {
  const _ResourceMeter({required this.result});

  final SandboxExecutionResult? result;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('sandbox-resource-meter'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          Text('Time ${result?.elapsed.inMilliseconds ?? 0} ms'),
          Text('Memory ${result?.peakMemoryBytes ?? 0} B'),
          Text('Fuel ${result?.fuelConsumed ?? 0}'),
        ],
      ),
    ),
  );
}

final class _ConsoleOutput extends StatelessWidget {
  const _ConsoleOutput({required this.result});

  final SandboxExecutionResult? result;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return Card(
      key: const Key('sandbox-console-output'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result == null
                  ? 'Console ready.'
                  : result.console.isNotEmpty
                  ? result.console
                  : result.reason ?? result.status.name,
            ),
            if (result?.artifact case final artifact?)
              _ArtifactView(artifact: artifact),
          ],
        ),
      ),
    );
  }
}

final class _ArtifactView extends StatelessWidget {
  const _ArtifactView({required this.artifact});

  final SandboxArtifact artifact;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('sandbox-render-artifact'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(),
      Text(artifact.title, style: Theme.of(context).textTheme.titleMedium),
      for (final value in artifact.values.take(50)) Text('• $value'),
    ],
  );
}
