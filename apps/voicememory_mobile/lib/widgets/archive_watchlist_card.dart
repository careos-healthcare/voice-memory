import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_copy.dart';
import '../features/archive_watchlist/archive_watchlist_engine.dart';
import '../features/archive_watchlist/archive_watchlist_gates.dart';
import '../features/archive_watchlist/archive_watchlist_models.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Local archive watchlist — themes to notice over time, no raw entry exposure.
class ArchiveWatchlistCard extends StatefulWidget {
  const ArchiveWatchlistCard({
    super.key,
    required this.entryCount,
    required this.entries,
    this.onAddMoment,
    this.store,
    this.engine = const ArchiveWatchlistEngine(),
    this._initialItems,
  });

  const ArchiveWatchlistCard.test({
    super.key,
    required this.entryCount,
    required this.entries,
    required this._initialItems,
    this.onAddMoment,
    this.store,
    this.engine = const ArchiveWatchlistEngine(),
  });

  final int entryCount;
  final List<JournalEntry> entries;
  final VoidCallback? onAddMoment;
  final ArchiveWatchlistStore? store;
  final ArchiveWatchlistEngine engine;
  final List<ArchiveWatchlistItem>? _initialItems;

  @override
  State<ArchiveWatchlistCard> createState() => _ArchiveWatchlistCardState();
}

class _ArchiveWatchlistCardState extends State<ArchiveWatchlistCard> {
  ArchiveWatchlistStore? _store;
  List<ArchiveWatchlistItem> _items = const [];
  bool _loading = true;
  bool _choosing = false;
  bool _showThemeLimit = false;
  String? _changingItemId;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    final initial = widget._initialItems;
    if (initial != null) {
      _items = List<ArchiveWatchlistItem>.from(initial);
      _loading = false;
      _choosing = _items.isEmpty;
      return;
    }
    if (_store == null) {
      _load();
      return;
    }
    _loadFromStore();
  }

  Future<void> _loadFromStore() async {
    final items = await _store!.loadItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      _choosing = items.isEmpty;
    });
  }

  Future<void> _load() async {
    _store ??= ArchiveWatchlistStore(AppServices.instance.prefs);
    await _loadFromStore();
  }

  ArchiveWatchlistCardResult get _result => widget.engine.build(
    entries: widget.entries,
    items: _items,
    entryCount: widget.entryCount,
  );

  Future<void> _addItem(ArchiveWatchlistItem item) async {
    if (!ArchiveWatchlistGates.canAddTheme(_items.length)) {
      setState(() => _showThemeLimit = true);
      return;
    }
    setState(() {
      _items = [..._items, item];
      _choosing = false;
      _showThemeLimit = false;
      _changingItemId = null;
    });
    await _store?.addItem(item);
  }

  Future<void> _replaceItem(ArchiveWatchlistItem item) async {
    final changingId = _changingItemId;
    if (changingId == null) {
      await _addItem(item);
      return;
    }
    setState(() {
      _items = _items
          .map((existing) => existing.id == changingId ? item : existing)
          .toList();
      _choosing = false;
      _changingItemId = null;
    });
    await _store?.removeItem(changingId);
    await _store?.addItem(item);
  }

  Future<void> _removeItem(String id) async {
    setState(() {
      _items = _items.where((item) => item.id != id).toList();
      _choosing = _items.isEmpty;
      _changingItemId = null;
      _showThemeLimit = false;
    });
    await _store?.removeItem(id);
  }

  Future<void> _pickCustomTheme() async {
    final label = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CustomThemeSheet(),
    );
    if (label == null || label.trim().isEmpty) return;
    final item = ArchiveWatchlistItem(
      id: _newItemId(),
      presetId: ArchiveWatchlistItem.customPresetId,
      customLabel: label.trim(),
      createdAt: DateTime.now(),
    );
    if (_changingItemId != null) {
      await _replaceItem(item);
    } else {
      await _addItem(item);
    }
  }

  String _newItemId() =>
      'watch_${DateTime.now().microsecondsSinceEpoch}_${_items.length}';

  Future<void> _selectPreset(ArchiveWatchlistPreset preset) async {
    final item = ArchiveWatchlistItem(
      id: _newItemId(),
      presetId: preset.id,
      createdAt: DateTime.now(),
    );
    if (_changingItemId != null) {
      await _replaceItem(item);
    } else {
      await _addItem(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('archive_watchlist_card_loading'));
    }

    if (ArchiveWatchlistGates.showTeaser(
      entryCount: widget.entryCount,
      sampleMode: false,
    )) {
      return _teaser(context);
    }

    if (!ArchiveWatchlistGates.showCard(
      entryCount: widget.entryCount,
      sampleMode: false,
    )) {
      return const SizedBox.shrink(key: Key('archive_watchlist_card_hidden'));
    }

    final result = _result;
    return Container(
      key: const Key('archive_watchlist_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: _choosing
          ? _chooseContent(context)
          : _savedContent(context, result),
    );
  }

  Widget _teaser(BuildContext context) {
    return Container(
      key: const Key('archive_watchlist_teaser'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveWatchlistCopy.teaserTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveWatchlistCopy.teaserBody,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
      ),
    );
  }

  Widget _chooseContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ArchiveWatchlistCopy.cardTitle,
          key: const Key('archive_watchlist_choose_title'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ArchiveWatchlistCopy.cardBody,
          key: const Key('archive_watchlist_choose_body'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final preset in ArchiveWatchlistCopy.presets) ...[
          _OptionButton(
            key: Key('archive_watchlist_option_${preset.id}'),
            label: preset.label,
            onTap: () => _selectPreset(preset),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        _OptionButton(
          key: const Key('archive_watchlist_option_custom'),
          label: ArchiveWatchlistCopy.customThemeButton,
          onTap: _pickCustomTheme,
        ),
        if (_showThemeLimit) ...[
          const SizedBox(height: AppSpacing.sm),
          _themeLimitBlock(context),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          ArchiveWatchlistCopy.privacyLine,
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
      ],
    );
  }

  Widget _savedContent(
    BuildContext context,
    ArchiveWatchlistCardResult result,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ArchiveWatchlistCopy.cardTitle,
          key: const Key('archive_watchlist_saved_title'),
          style: ArchiveMobileTypography.cardLabel(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final itemResult in result.itemResults) ...[
          _itemBlock(context, itemResult),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (result.showProLine) ...[
          Text(
            ArchiveWatchlistCopy.proLineLongTerm,
            key: const Key('archive_watchlist_pro_line'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('archive_watchlist_pro_preview_button'),
              onPressed: () => context.push('/pro-preview'),
              child: const Text(ArchiveWatchlistCopy.proPreviewButton),
            ),
          ),
        ],
        if (_showThemeLimit) ...[
          const SizedBox(height: AppSpacing.xs),
          _themeLimitBlock(context),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (ArchiveWatchlistGates.canAddTheme(_items.length))
              OutlinedButton(
                key: const Key('archive_watchlist_add_theme_button'),
                onPressed: () => setState(() {
                  _choosing = true;
                  _changingItemId = null;
                }),
                child: const Text(ArchiveWatchlistCopy.addThemeButton),
              ),
            if (widget.onAddMoment != null)
              FilledButton(
                key: const Key('archive_watchlist_add_moment_button'),
                onPressed: widget.onAddMoment,
                child: const Text('Add a moment'),
              ),
          ],
        ),
        Text(
          ArchiveWatchlistCopy.privacyLine,
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
      ],
    );
  }

  Widget _itemBlock(
    BuildContext context,
    ArchiveWatchlistItemResult itemResult,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ArchiveWatchlistCopy.watchingForLine(itemResult.label),
          key: Key('archive_watchlist_watching_${itemResult.item.id}'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ArchiveWatchlistCopy.addWhenShowsUp,
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          itemResult.hasMatches
              ? ArchiveWatchlistCopy.matchHeadline
              : ArchiveWatchlistCopy.noMatchHeadline,
          key: Key(
            itemResult.hasMatches
                ? 'archive_watchlist_match_${itemResult.item.id}'
                : 'archive_watchlist_no_match_${itemResult.item.id}',
          ),
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          itemResult.hasMatches
              ? ArchiveWatchlistCopy.matchCountLine(itemResult.matchCount)
              : ArchiveWatchlistCopy.noMatchBody,
          key: Key('archive_watchlist_match_line_${itemResult.item.id}'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton(
              key: Key('archive_watchlist_change_${itemResult.item.id}'),
              onPressed: () => setState(() {
                _choosing = true;
                _changingItemId = itemResult.item.id;
              }),
              child: const Text(ArchiveWatchlistCopy.changeThemeButton),
            ),
            TextButton(
              key: Key('archive_watchlist_remove_${itemResult.item.id}'),
              onPressed: () => _removeItem(itemResult.item.id),
              child: const Text(ArchiveWatchlistCopy.removeThemeButton),
            ),
          ],
        ),
      ],
    );
  }

  Widget _themeLimitBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ArchiveWatchlistCopy.themeLimitBody,
          key: const Key('archive_watchlist_theme_limit_body'),
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('archive_watchlist_theme_limit_pro_button'),
            onPressed: () => context.push('/pro-preview'),
            child: const Text(ArchiveWatchlistCopy.proPreviewButton),
          ),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomThemeSheet extends StatefulWidget {
  const _CustomThemeSheet();

  @override
  State<_CustomThemeSheet> createState() => _CustomThemeSheetState();
}

class _CustomThemeSheetState extends State<_CustomThemeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveWatchlistCopy.customThemeSheetTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('archive_watchlist_custom_theme_field'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: ArchiveWatchlistCopy.customThemeHint,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('archive_watchlist_custom_theme_save'),
            onPressed: () => _save(context),
            child: const Text(ArchiveWatchlistCopy.customThemeSave),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(ArchiveWatchlistCopy.customThemeCancel),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }
}
