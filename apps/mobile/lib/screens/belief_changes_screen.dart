import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/archive_beliefs/belief_change_timeline.dart';
import 'package:archiveme_mobile/features/archive_changes/archive_changes_adapter.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/router/archive_changes_deep_link.dart';
import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:archiveme_mobile/router/primary_navigation_controller.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/accessibility/accessible_primary_surface.dart';
import 'package:archiveme_mobile/widgets/archive/archive_beliefs_dashboard.dart';
import 'package:archiveme_mobile/widgets/belief_empty_state.dart';
import 'package:archiveme_mobile/widgets/consumer/consumer_screen_back_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Historical Changes presentation — owned by Archive via [ArchiveChangesAdapter].
class BeliefChangesScreen extends StatefulWidget {
  const BeliefChangesScreen({super.key, this.previewTimeline});

  /// Test-only: skip async load and render this timeline.
  @visibleForTesting
  final List<BeliefChangeTimelineItem>? previewTimeline;

  @override
  State<BeliefChangesScreen> createState() => _BeliefChangesScreenState();
}

class _BeliefChangesScreenState extends State<BeliefChangesScreen> {
  ArchiveChangesSnapshot? _snapshot;
  bool _loading = true;
  bool _redirectedIneligible = false;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewTimeline;
    if (preview != null) {
      _snapshot = ArchiveChangesSnapshot(
        entries: const [],
        timeline: preview,
        eligible: preview.isNotEmpty,
      );
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_snapshot != null) {
          _redirectIfLegacyDeepLinkIneligible(_snapshot!);
        }
      });
      return;
    }
    primaryNavigationController.addListener(_handlePrimaryActivation);
    unawaited(_load());
  }

  @override
  void dispose() {
    primaryNavigationController.removeListener(_handlePrimaryActivation);
    super.dispose();
  }

  void _handlePrimaryActivation() {
    if (!mounted || _loading || widget.previewTimeline != null) return;
    if (primaryNavigationController.activeDestination !=
        PrimaryDestination.archive) {
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snapshot = await ArchiveChangesAdapter.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
    _redirectIfLegacyDeepLinkIneligible(snapshot);
  }

  void _redirectIfLegacyDeepLinkIneligible(ArchiveChangesSnapshot snapshot) {
    if (_redirectedIneligible || !mounted || widget.previewTimeline != null && snapshot.eligible) {
      return;
    }
    if (!_isLegacyChangesRoute(context) || snapshot.eligible) return;
    _redirectedIneligible = true;
    context.go(ArchiveChangesDeepLink.archiveWithUnavailableNotice());
  }

  bool _isLegacyChangesRoute(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return path == RouteCatalog.changesHome ||
        path == ArchiveChangesDeepLink.nestedChangesPath;
  }

  bool get _showEmpty {
    if (ScreenshotMode.enabled) return false;
    final snapshot = _snapshot;
    if (snapshot == null) return true;
    if (snapshot.timeline.isNotEmpty) return false;
    return isIntentionalEmptyArchive(snapshot.entries);
  }

  List<Widget> _pageHeader() {
    return [
      const ConsumerScreenBackHeader(fallbackRoute: RouteCatalog.archiveHome),
      Text(
        ConsumerUiCopy.changesScreenTitle,
        style: VoiceMemoryTypography.headlineStyle(),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        ConsumerUiCopy.changesScreenLead,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textSecondary,
        ).copyWith(fontSize: 18),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading &&
        _snapshot != null &&
        !_snapshot!.eligible &&
        _isLegacyChangesRoute(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _redirectIfLegacyDeepLinkIneligible(_snapshot!);
      });
      return _primarySurface(
        const Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: SizedBox.shrink(),
        ),
      );
    }

    if (_loading) {
      return _primarySurface(
        const Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: SafeArea(
            child: Padding(
              padding: ArchiveMobileSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Center(child: CircularProgressIndicator())],
              ),
            ),
          ),
        ),
      );
    }

    if (_showEmpty && isIntentionalEmptyArchive(_snapshot?.entries ?? const [])) {
      return _primarySurface(
        Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: ArchiveMobileSpacing.pagePadding,
                children: [
                  ..._pageHeader(),
                  const BeliefEmptyState(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final timeline = _snapshot?.timeline ?? const [];
    return _primarySurface(
      Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: ArchiveMobileSpacing.pagePadding,
              children: [
                ..._pageHeader(),
                BeliefChangeStories(items: timeline),
                if (timeline.isEmpty) ...[
                  Text(
                    ConsumerUiCopy.changesEmptyLead,
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primarySurface(Widget child) =>
      AccessiblePrimarySurface(label: 'Changes screen', child: child);
}
