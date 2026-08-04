import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../storage/app_storage_paths.dart';
import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../cognitive_council/council_persona.dart';
import '../../semantic_clusters/semantic_cluster.dart';
import '../persona_forge_service.dart';
import '../persona_knowledge_router.dart';

typedef PersonaPlaygroundResponder =
    Future<String> Function(PersonaInvocationRequest request);

class PersonaStudioSheet extends StatefulWidget {
  const PersonaStudioSheet({
    super.key,
    required this.service,
    required this.knowledgeRouter,
    required this.clusters,
    this.playgroundResponder,
    this.onOpenNeuralStudio,
    this.onClose,
  });

  final PersonaForgeService service;
  final PersonaKnowledgeRouter knowledgeRouter;
  final List<SemanticCluster> clusters;
  final PersonaPlaygroundResponder? playgroundResponder;
  final Future<void> Function()? onOpenNeuralStudio;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required PersonaForgeService service,
    required PersonaKnowledgeRouter knowledgeRouter,
    required List<SemanticCluster> clusters,
    PersonaPlaygroundResponder? playgroundResponder,
    Future<void> Function()? onOpenNeuralStudio,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'persona-forge',
    builder: (panelContext) => PersonaStudioSheet(
      service: service,
      knowledgeRouter: knowledgeRouter,
      clusters: clusters,
      playgroundResponder: playgroundResponder,
      onOpenNeuralStudio: onOpenNeuralStudio,
      onClose: () => Navigator.of(panelContext).pop(),
    ),
  );

  @override
  State<PersonaStudioSheet> createState() => _PersonaStudioSheetState();
}

class _PersonaStudioSheetState extends State<PersonaStudioSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _archetype = TextEditingController();
  final _prompt = TextEditingController();
  final _message = TextEditingController();
  final _chat = <({bool user, String text})>[];
  List<CouncilPersona> _personas = const [];
  CouncilPersona? _selected;
  Set<String> _clusterIds = {};
  String _avatarAsset = 'psychology';
  double _temperature = .5;
  bool _loading = true;
  bool _saving = false;
  bool _responding = false;

  static const _avatars = <String, IconData>{
    'psychology': Icons.psychology_alt_outlined,
    'compass': Icons.explore_outlined,
    'strategist': Icons.account_tree_outlined,
    'wellbeing': Icons.spa_outlined,
    'creative': Icons.auto_awesome_outlined,
  };

  @override
  void initState() {
    super.initState();
    _name.addListener(_draftChanged);
    _archetype.addListener(_draftChanged);
    _prompt.addListener(_draftChanged);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _name.removeListener(_draftChanged);
    _archetype.removeListener(_draftChanged);
    _prompt.removeListener(_draftChanged);
    _name.dispose();
    _archetype.dispose();
    _prompt.dispose();
    _message.dispose();
    super.dispose();
  }

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  bool get _draftValid =>
      _name.text.trim().isNotEmpty &&
      _archetype.text.trim().isNotEmpty &&
      _prompt.text.trim().isNotEmpty;

  Future<void> _reload() async {
    final personas = await widget.service.list();
    if (!mounted) return;
    setState(() {
      _personas = personas;
      _loading = false;
    });
  }

  void _select(CouncilPersona? persona) {
    setState(() {
      _selected = persona;
      _name.text = persona?.name ?? '';
      _archetype.text = persona?.archetypeTitle ?? '';
      _prompt.text = persona?.systemPrompt ?? '';
      _avatarAsset = persona?.avatarAsset ?? 'psychology';
      _temperature = persona?.temperature ?? .5;
      _clusterIds = {...?persona?.restrictedClusterIds};
      _chat.clear();
    });
  }

  CouncilPersona _draft() {
    final selected = _selected;
    return CouncilPersona(
      id: selected?.id ?? 'persona-playground-draft',
      name: _name.text,
      avatarAsset: _avatarAsset,
      avatarImage: selected?.avatarImage,
      archetypeTitle: _archetype.text,
      systemPrompt: _prompt.text,
      localizedSystemPrompts: selected?.localizedSystemPrompts ?? const {},
      temperature: _temperature,
      restrictedClusterIds: _clusterIds,
      createdAt: selected?.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final draft = _draft();
      final persona = _selected == null
          ? await widget.service.create(
              name: draft.name,
              avatarAsset: draft.avatarAsset,
              archetypeTitle: draft.archetypeTitle,
              systemPrompt: draft.systemPrompt,
              temperature: draft.temperature,
              restrictedClusterIds: draft.restrictedClusterIds,
            )
          : await widget.service.update(draft);
      await _reload();
      if (!mounted) return;
      _select(_personas.firstWhere((item) => item.id == persona.id));
      _notice('Persona saved to the encrypted local forge.');
    } on Object catch (error) {
      _notice('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final selected = _selected;
    if (selected == null) return;
    await widget.service.delete(selected.id);
    _select(null);
    await _reload();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _responding || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _responding = true;
      _message.clear();
      _chat.add((user: true, text: text));
    });
    try {
      final request = await widget.knowledgeRouter.buildInvocation(
        persona: _draft(),
        userMessage: text,
        localeTag: Localizations.localeOf(context).toLanguageTag(),
      );
      final response =
          await (widget.playgroundResponder?.call(request) ??
              Future.value(
                '${_name.text} is ready. I can reason from '
                '${request.context.nodes.length} permitted graph nodes while '
                'keeping all other clusters out of scope.',
              ));
      if (mounted) setState(() => _chat.add((user: false, text: response)));
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _chat.add((user: false, text: 'Playground error: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  Future<void> _export() async {
    final persona = _selected;
    if (persona == null) return;
    final password = await _passwordDialog('Encrypt persona package');
    if (password == null) return;
    final directory = await AppStoragePaths.temporaryDirectory();
    final safeName = persona.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = await widget.service.exportPersona(
      persona: persona,
      output: File('${directory.path}/$safeName.persona'),
      passphrase: password,
    );
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/octet-stream'),
    ], subject: '${persona.name} persona');
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['persona'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final password = await _passwordDialog('Unlock persona package');
    if (password == null) return;
    try {
      final persona = await widget.service.importPersona(
        input: File(path),
        passphrase: password,
      );
      await _reload();
      if (mounted) {
        _select(_personas.firstWhere((item) => item.id == persona.id));
      }
    } on Object catch (error) {
      _notice('$error');
    }
  }

  Future<String?> _passwordDialog(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Package password',
            helperText: 'At least 12 characters',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('persona-studio-sheet'),
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            _header(theme),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                        children: [
                          _personaSelector(),
                          const SizedBox(height: 14),
                          _builderCard(theme),
                          const SizedBox(height: 14),
                          _permissionsCard(theme),
                          const SizedBox(height: 14),
                          _playgroundCard(theme),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
    child: Row(
      children: [
        Icon(Icons.theater_comedy_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The Persona Forge', style: theme.textTheme.titleLarge),
              Text(
                'Encrypted locally · cluster-scoped',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('persona-open-neural-studio'),
          tooltip: 'Open Neural Sculptor',
          onPressed: widget.onOpenNeuralStudio == null
              ? null
              : () => unawaited(widget.onOpenNeuralStudio!()),
          icon: const Icon(Icons.hub_outlined),
        ),
        IconButton(
          key: const Key('persona-import'),
          tooltip: 'Import .persona',
          onPressed: _import,
          icon: const Icon(Icons.file_download_outlined),
        ),
        IconButton(
          key: const Key('persona-export'),
          tooltip: 'Export .persona',
          onPressed: _selected == null ? null : _export,
          icon: const Icon(Icons.ios_share_outlined),
        ),
        IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
      ],
    ),
  );

  Widget _personaSelector() => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<CouncilPersona?>(
          key: ValueKey('persona-selector-${_selected?.id ?? 'new'}'),
          initialValue: _selected,
          decoration: const InputDecoration(labelText: 'Saved persona'),
          items: [
            const DropdownMenuItem(value: null, child: Text('New persona')),
            for (final persona in _personas)
              DropdownMenuItem(value: persona, child: Text(persona.name)),
          ],
          onChanged: _select,
        ),
      ),
      if (_selected != null)
        IconButton(
          key: const Key('persona-delete'),
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );

  Widget _builderCard(ThemeData theme) => Card(
    color: theme.colorScheme.surface.withValues(alpha: .54),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Persona builder', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('persona-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: _required,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('persona-archetype'),
            controller: _archetype,
            decoration: const InputDecoration(labelText: 'Archetype title'),
            validator: _required,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('persona-prompt'),
            controller: _prompt,
            minLines: 4,
            maxLines: 9,
            maxLength: 12000,
            decoration: const InputDecoration(
              labelText: 'System prompt',
              alignLabelWithHint: true,
            ),
            validator: _required,
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _avatars.entries)
                ChoiceChip(
                  key: Key('persona-avatar-${entry.key}'),
                  selected: _avatarAsset == entry.key,
                  avatar: Icon(entry.value, size: 18),
                  label: Text(entry.key),
                  onSelected: (_) => setState(() => _avatarAsset = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Creativity ${_temperature.toStringAsFixed(2)}'),
          Slider(
            key: const Key('persona-temperature'),
            value: _temperature,
            divisions: 20,
            onChanged: (value) => setState(() => _temperature = value),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('persona-save'),
              onPressed: _saving || !_draftValid ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Deploy to Council'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _permissionsCard(ThemeData theme) => Card(
    color: theme.colorScheme.surface.withValues(alpha: .54),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Graph permissions', style: theme.textTheme.titleMedium),
          const Text(
            'No selection means this persona receives no Memory Graph context.',
          ),
          for (final cluster in widget.clusters)
            CheckboxListTile(
              key: Key('persona-cluster-${cluster.id}'),
              contentPadding: EdgeInsets.zero,
              value: _clusterIds.contains(cluster.id),
              title: Text(cluster.title),
              subtitle: Text(
                '${cluster.category.wireName} · ${cluster.nodeIds.length} nodes',
              ),
              onChanged: (selected) => setState(() {
                if (selected == true) {
                  _clusterIds.add(cluster.id);
                } else {
                  _clusterIds.remove(cluster.id);
                }
              }),
            ),
        ],
      ),
    ),
  );

  Widget _playgroundCard(ThemeData theme) => Card(
    color: theme.colorScheme.surface.withValues(alpha: .54),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Test Playground', style: theme.textTheme.titleMedium),
          const Text('Sandbox messages are not retained.'),
          if (_chat.isNotEmpty)
            Container(
              key: const Key('persona-playground-chat'),
              constraints: const BoxConstraints(maxHeight: 220),
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in _chat)
                    Align(
                      alignment: item.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.user
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(item.text),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('persona-playground-input'),
                  controller: _message,
                  decoration: const InputDecoration(
                    hintText: 'Ask your persona…',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                key: const Key('persona-playground-send'),
                onPressed: _responding ? null : _send,
                icon: _responding
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}
