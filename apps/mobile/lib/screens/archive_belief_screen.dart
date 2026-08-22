import 'dart:async';

import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_dashboard_scroll_view.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/archive_feed_providers.dart';
import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/router/archive_changes_deep_link.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Archive: the user's original saved moments, plus verified changes when the
/// canonical proof pipeline admits one. See `docs/ARCHIVE_SCREEN_SPEC_V1.md`.
class ArchiveBeliefScreen extends StatefulWidget {
  const ArchiveBeliefScreen({
    super.key,
    this.journalStore,
    this.journalSqliteRepository,
  });

  /// Test harness overrides — production resolves from Riverpod holders.
  final JournalStore? journalStore;
  final JournalSqliteRepository? journalSqliteRepository;

  @override
  State<ArchiveBeliefScreen> createState() => _ArchiveBeliefScreenState();
}

class _ArchiveBeliefScreenState extends State<ArchiveBeliefScreen> {
  late final ScrollController _scrollController;
  ProviderContainer? _scopedContainer;
  ProviderSubscription<ArchiveFeedState>? _feedSubscription;

  ArchiveFeedPaginationNotifier get _feedNotifier {
    if (_scopedContainer != null) {
      return _scopedContainer!.read(archiveFeedPaginationProvider.notifier);
    }
    return appProviderContainer.read(archiveFeedPaginationProvider.notifier);
  }

  ArchiveFeedState get _feedState {
    if (_scopedContainer != null) {
      return _scopedContainer!.read(archiveFeedPaginationProvider);
    }
    return appProviderContainer.read(archiveFeedPaginationProvider);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _configureScopedContainerIfNeeded();
    _attachFeedListener();
    unawaited(BetaAnalyticsHooks.archiveFirstViewed());
    // `ArchiveFeedPaginationNotifier.refresh` writes `state` before its first
    // await whenever the feed is still on its initial load, which is always
    // true on first mount, so calling it straight from `initState` mutates a
    // provider mid-build. Run it once the frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refresh());
    });
  }

  void _configureScopedContainerIfNeeded() {
    if (widget.journalStore == null && widget.journalSqliteRepository == null) {
      return;
    }
    final parent = appProviderContainer;
    _scopedContainer = ProviderContainer(
      parent: parent,
      overrides: [
        if (widget.journalStore != null)
          journalStoreProvider.overrideWithValue(widget.journalStore!),
        if (widget.journalSqliteRepository != null)
          journalSqliteRepositoryProvider.overrideWithValue(
            widget.journalSqliteRepository!,
          ),
      ],
    );
  }

  void _attachFeedListener() {
    final container = _scopedContainer ?? appProviderContainer;
    _feedSubscription?.close();
    _feedSubscription = container.listen<ArchiveFeedState>(
      archiveFeedPaginationProvider,
      (_, _) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _feedSubscription?.close();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _scopedContainer?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      unawaited(_feedNotifier.loadNextPage());
    }
  }

  Future<void> _refresh() async {
    await _feedNotifier.refresh();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openEntry(String entryId) async {
    await context.push('/entry/$entryId');
    await _refresh();
  }

  void _onQueryChanged(String value) {
    unawaited(_feedNotifier.updateSearchQuery(value));
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feedState;
    final uri = GoRouter.maybeOf(context)?.state.uri ??
        Uri(path: RouteCatalog.archiveHome);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(title: const Text('Archive')),
      body: SafeArea(
        child: ArchiveDashboardScrollView(
          controller: _scrollController,
          feed: feed,
          loadState: feed.loadState,
          visibleEntries: feed.entries,
          showChangesUnavailable: ArchiveChangesDeepLink.showsUnavailableNotice(
            uri,
          ),
          onRefresh: _refresh,
          onEntryTap: (entryId) => unawaited(_openEntry(entryId)),
          onQueryChanged: _onQueryChanged,
          onCapture: () {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              router.go('/record');
            }
          },
        ),
      ),
    );
  }
}
