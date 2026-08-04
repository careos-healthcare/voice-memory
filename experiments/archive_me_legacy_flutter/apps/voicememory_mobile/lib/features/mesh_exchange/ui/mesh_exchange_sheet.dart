import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/graph/personal_knowledge_graph.dart';
import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../cognitive_council/council_persona.dart';
import '../../semantic_clusters/semantic_cluster.dart';
import '../mesh_exchange_models.dart';
import '../mesh_exchange_service.dart';
import '../mesh_import_validator.dart';

typedef MeshScannerBuilder = Widget Function(ValueChanged<String> onPayload);
typedef MeshPackageReady = FutureOr<void> Function(MeshExchangePackage package);
typedef MeshDiffLoader = Future<MeshImportDiff> Function(Uint8List envelope);
typedef MeshDiffApprover = Future<void> Function(MeshImportDiff diff);

final class MeshExchangeSheet extends StatefulWidget {
  const MeshExchangeSheet({
    required this.exchange,
    required this.validator,
    required this.graph,
    required this.clusters,
    required this.personas,
    this.scannerBuilder,
    this.onPackageReady,
    this.diffLoader,
    this.diffApprover,
    this.onClose,
    super.key,
  });

  final MeshExchangeService exchange;
  final MeshImportValidator validator;
  final PersonalKnowledgeGraph graph;
  final List<SemanticCluster> clusters;
  final List<CouncilPersona> personas;
  final MeshScannerBuilder? scannerBuilder;
  final MeshPackageReady? onPackageReady;
  final MeshDiffLoader? diffLoader;
  final MeshDiffApprover? diffApprover;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required MeshExchangeService exchange,
    required MeshImportValidator validator,
    required PersonalKnowledgeGraph graph,
    required List<SemanticCluster> clusters,
    required List<CouncilPersona> personas,
    MeshPackageReady? onPackageReady,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'mesh-exchange',
    builder: (panelContext) => MeshExchangeSheet(
      exchange: exchange,
      validator: validator,
      graph: graph,
      clusters: clusters,
      personas: personas,
      onPackageReady: onPackageReady,
      onClose: () => Navigator.pop(panelContext),
    ),
  );

  @override
  State<MeshExchangeSheet> createState() => _MeshExchangeSheetState();
}

class _MeshExchangeSheetState extends State<MeshExchangeSheet> {
  final _recipientCode = TextEditingController();
  final _assembler = MeshQrAssembler();
  final _selectedPersonas = <String>{};
  var _mode = 0;
  String? _clusterId;
  var _policy = MeshExchangePolicy.reusable;
  MeshExchangeInvitation? _invitation;
  MeshExchangePackage? _package;
  MeshImportDiff? _diff;
  var _scanning = false;
  var _busy = false;
  var _frameIndex = 0;
  var _scanProgress = 0.0;
  String? _message;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _clusterId = widget.clusters.firstOrNull?.id;
    unawaited(_createInvitation());
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _recipientCode.dispose();
    super.dispose();
  }

  Future<void> _createInvitation() async {
    try {
      final invitation = await widget.exchange.createInvitation();
      if (mounted) setState(() => _invitation = invitation);
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final invitation = MeshExchangeInvitation.decode(_recipientCode.text);
      final cluster = widget.clusters
          .where((item) => item.id == _clusterId)
          .firstOrNull;
      final selectedNodeIds =
          cluster?.nodeIds ??
          widget.graph.nodes.map((item) => item.id).take(50).toList();
      final localIdentity = await widget.exchange.identity.identity();
      final content = widget.exchange.buildContent(
        senderName: localIdentity.deviceId,
        graph: widget.graph,
        selectedNodeIds: selectedNodeIds,
        clusters: cluster == null ? const [] : [cluster],
        personas: widget.personas.where(
          (item) => _selectedPersonas.contains(item.id),
        ),
        policy: _policy,
        destructAt: _policy == MeshExchangePolicy.selfDestruct
            ? DateTime.now().toUtc().add(const Duration(hours: 24))
            : null,
      );
      final result = await widget.exchange.package(
        invitation: invitation,
        content: content,
      );
      await widget.onPackageReady?.call(result);
      if (mounted) {
        setState(() {
          _package = result;
          _frameIndex = 0;
        });
        _animationTimer?.cancel();
        if (result.frames.length > 1) {
          _animationTimer = Timer.periodic(const Duration(milliseconds: 850), (
            _,
          ) {
            if (mounted && _package == result) {
              setState(
                () => _frameIndex = (_frameIndex + 1) % result.frames.length,
              );
            }
          });
        }
      }
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan(String payload) async {
    try {
      if (payload.startsWith('vm-mesh-exchange://invite/')) {
        _recipientCode.text = payload;
        setState(() {
          _mode = 0;
          _scanning = false;
          _message = 'Recipient handshake captured.';
        });
        return;
      }
      final bytes = _assembler.add(payload);
      setState(() => _scanProgress = _assembler.progress);
      if (bytes == null) return;
      setState(() {
        _busy = true;
        _scanning = false;
      });
      final diff =
          await widget.diffLoader?.call(bytes) ??
          await widget.validator.validate(
            envelope: bytes,
            localGraph: widget.graph,
            localPersonas: widget.personas,
          );
      if (mounted) setState(() => _diff = diff);
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final diff = _diff;
    if (diff == null) return;
    setState(() => _busy = true);
    try {
      if (widget.diffApprover case final approver?) {
        await approver(diff);
      } else {
        await widget.validator.approve(diff);
      }
      if (mounted) {
        setState(() {
          _diff = null;
          _message = '${diff.provenance} imported as an isolated branch.';
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.hub_outlined),
                const SizedBox(width: 10),
                Text('The Mesh Exchange', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SegmentedButton<int>(
              key: const Key('mesh-exchange-mode'),
              segments: const [
                ButtonSegment(value: 0, label: Text('Export')),
                ButtonSegment(value: 1, label: Text('Import')),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => setState(() {
                _mode = value.single;
                _scanning = false;
              }),
            ),
            const SizedBox(height: 12),
            if (_message case final message?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(message, key: const Key('mesh-exchange-message')),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _mode == 0 ? _exportView() : _importView(),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _exportView() {
    final result = _package;
    if (result != null) {
      final frame = result.frames[_frameIndex];
      return ListView(
        key: const Key('mesh-export-result'),
        children: [
          const Text('Encrypted animated QR package'),
          const SizedBox(height: 12),
          Center(
            child: ColoredBox(
              color: Colors.white,
              child: QrImageView(
                key: const Key('mesh-export-qr'),
                data: frame.encode(),
                size: 230,
              ),
            ),
          ),
          Slider(
            key: const Key('mesh-qr-frame-slider'),
            value: _frameIndex.toDouble(),
            max: (result.frames.length - 1).clamp(1, 10000).toDouble(),
            divisions: result.frames.length > 1 ? result.frames.length - 1 : 1,
            label: '${_frameIndex + 1}/${result.frames.length}',
            onChanged: result.frames.length == 1
                ? null
                : (value) => setState(() => _frameIndex = value.round()),
          ),
          Text(
            'Frame ${_frameIndex + 1} of ${result.frames.length}. '
            'The binary package is also ready for nearby AirDrop/P2P transfer.',
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () {
              _animationTimer?.cancel();
              setState(() => _package = null);
            },
            child: const Text('Create another'),
          ),
        ],
      );
    }
    return ListView(
      key: const Key('mesh-export-config'),
      children: [
        const Text(
          'Scan or paste the recipient’s one-time handshake. The payload key '
          'is derived by X25519 and never leaves either device.',
        ),
        TextField(
          key: const Key('mesh-recipient-code'),
          controller: _recipientCode,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Recipient QR handshake',
          ),
        ),
        if (widget.clusters.isNotEmpty)
          DropdownButtonFormField<String>(
            key: const Key('mesh-cluster-picker'),
            initialValue: _clusterId,
            decoration: const InputDecoration(labelText: 'Semantic cluster'),
            items: [
              for (final cluster in widget.clusters)
                DropdownMenuItem(value: cluster.id, child: Text(cluster.title)),
            ],
            onChanged: (value) => setState(() => _clusterId = value),
          ),
        for (final persona in widget.personas)
          CheckboxListTile(
            key: Key('mesh-persona-${persona.id}'),
            value: _selectedPersonas.contains(persona.id),
            title: Text(persona.name),
            subtitle: const Text('Include encrypted custom persona'),
            onChanged: (selected) => setState(() {
              if (selected ?? false) {
                _selectedPersonas.add(persona.id);
              } else {
                _selectedPersonas.remove(persona.id);
              }
            }),
          ),
        DropdownButtonFormField<MeshExchangePolicy>(
          key: const Key('mesh-policy-picker'),
          initialValue: _policy,
          decoration: const InputDecoration(labelText: 'Access policy'),
          items: const [
            DropdownMenuItem(
              value: MeshExchangePolicy.reusable,
              child: Text('Reusable'),
            ),
            DropdownMenuItem(
              value: MeshExchangePolicy.readOnce,
              child: Text('Read once'),
            ),
            DropdownMenuItem(
              value: MeshExchangePolicy.selfDestruct,
              child: Text('Self-destruct after 24 hours'),
            ),
          ],
          onChanged: (value) => setState(() => _policy = value!),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('mesh-generate-package'),
          onPressed: _busy ? null : _generate,
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Generate Secure QR / AirDrop Package'),
        ),
      ],
    );
  }

  Widget _importView() {
    final diff = _diff;
    if (diff != null) return _diffView(diff);
    if (_scanning) {
      return Column(
        key: const Key('mesh-import-scanner'),
        children: [
          LinearProgressIndicator(value: _scanProgress),
          Text('${(_scanProgress * 100).round()}% decoded'),
          const SizedBox(height: 8),
          Expanded(
            child:
                widget.scannerBuilder?.call(_scan) ??
                MobileScanner(
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      final value = barcode.rawValue;
                      if (value != null) {
                        unawaited(_scan(value));
                        break;
                      }
                    }
                  },
                ),
          ),
          TextButton(
            onPressed: () => setState(() => _scanning = false),
            child: const Text('Cancel scanner'),
          ),
        ],
      );
    }
    return ListView(
      key: const Key('mesh-import-handshake'),
      children: [
        const Text(
          'Show this one-time QR to the sender. Then scan every encrypted '
          'payload frame. Nothing is routed through a cloud service.',
        ),
        if (_invitation case final invitation?)
          Center(
            child: ColoredBox(
              color: Colors.white,
              child: QrImageView(
                key: const Key('mesh-invitation-qr'),
                data: invitation.encode(),
                size: 230,
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('mesh-start-scanner'),
          onPressed: _invitation == null
              ? null
              : () => setState(() => _scanning = true),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan incoming animated QR'),
        ),
      ],
    );
  }

  Widget _diffView(MeshImportDiff diff) => ListView(
    key: const Key('mesh-import-diff'),
    children: [
      Text(diff.provenance, style: Theme.of(context).textTheme.titleMedium),
      Text('Signer ${diff.signerFingerprint}'),
      _countCard('Nodes', diff.nodeCount, diff.conflictingNodeIds.length),
      _countCard('Edges', diff.edgeCount, 0),
      _countCard(
        'Personas',
        diff.personaCount,
        diff.conflictingPersonaIds.length,
      ),
      _countCard('Journal fragments', diff.fragmentCount, 0),
      if (diff.hasConflicts)
        Card(
          key: const Key('mesh-conflict-card'),
          child: const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Conflicting IDs detected'),
            subtitle: Text(
              'Existing records will not be overwritten. All received data '
              'stays in an isolated incoming cluster.',
            ),
          ),
        ),
      FilledButton.icon(
        key: const Key('mesh-approve-import'),
        onPressed: _busy ? null : _approve,
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('Approve isolated import'),
      ),
      TextButton(
        onPressed: () => setState(() => _diff = null),
        child: const Text('Reject'),
      ),
    ],
  );

  Widget _countCard(String label, int count, int conflicts) => Card(
    child: ListTile(
      title: Text(label),
      trailing: Text('$count'),
      subtitle: conflicts == 0 ? null : Text('$conflicts conflicts'),
    ),
  );
}
