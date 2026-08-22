import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/coach/coach_copy.dart';
import 'package:archiveme_mobile/features/coach/coach_mode_controller.dart';
import 'package:archiveme_mobile/features/coach/coach_read_service.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Read-only coach dashboard for session planning — isolated from caregiver monitoring.
class CoachDashboardView extends StatefulWidget {
  const CoachDashboardView({
    super.key,
    this.readService,
    this.modeController,
  });

  final CoachReadService? readService;
  final CoachModeController? modeController;

  @override
  State<CoachDashboardView> createState() => _CoachDashboardViewState();
}

class _CoachDashboardViewState extends State<CoachDashboardView> {
  CoachDashboardSnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  CoachModeController get _controller =>
      widget.modeController ?? CoachModeController.instance;

  CoachReadService get _readService =>
      widget.readService ??
      CoachReadService(
        journalStore: AppServices.instance.journalStore,
        factLedgerStore: FactLedgerStore(AppServices.instance.prefs),
        modeController: _controller,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _controller.initialize();
    if (!_controller.hasValidSession) {
      await _controller.activateFromStoredClientToken();
    }
    if (!_controller.hasValidSession) {
      setState(() {
        _loading = false;
        _error = CoachCopy.noSessionMessage;
      });
      return;
    }
    final snapshot = await _readService.loadDashboardSnapshot();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _snapshot = snapshot;
      _error = snapshot == null ? CoachCopy.noSessionMessage : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: CoachCopy.dashboardTitle,
      showBottomDone: false,
      fallbackRoute: RouteCatalog.accountHome,
      actions: [
        TextButton(
          onPressed: () => unawaited(_exitCoachMode(context)),
          child: const Text(CoachCopy.switchToSelfCta),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _messageBody(_error!)
              : _dashboardBody(context, _snapshot!),
    );
  }

  Widget _messageBody(String message) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(message, style: ArchiveMobileTypography.explanationBody(context)),
    );
  }

  Widget _dashboardBody(BuildContext context, CoachDashboardSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                CoachCopy.readOnlyBadge,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          CoachCopy.dashboardSubtitle,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        _insightSection(
          context,
          title: CoachCopy.beliefsLabel,
          rows: snapshot.beliefs,
        ),
        _insightSection(
          context,
          title: CoachCopy.blindSpotsLabel,
          rows: snapshot.blindSpots,
        ),
        _insightSection(
          context,
          title: CoachCopy.contradictionsLabel,
          rows: snapshot.contradictions,
        ),
        if (snapshot.factLedgerLabels.isNotEmpty)
          _section(
            context,
            title: CoachCopy.factLedgerLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: snapshot.factLedgerLabels
                  .map(
                    (label) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text('• $label'),
                    ),
                  )
                  .toList(),
            ),
          ),
        Text(
          CoachCopy.auditNotice,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
      ],
    );
  }

  Widget _insightSection(
    BuildContext context, {
    required String title,
    required List<CoachSessionInsightRow> rows,
  }) {
    if (rows.isEmpty) {
      return _section(
        context,
        title: title,
        child: const Text(CoachCopy.emptySectionMessage),
      );
    }
    return _section(
      context,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows.map((row) => _insightCard(context, row)).toList(),
      ),
    );
  }

  Widget _insightCard(BuildContext context, CoachSessionInsightRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.title, style: ArchiveMobileTypography.sectionTitle(context)),
              if (row.confidenceBand != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Confidence: ${row.confidenceBand}',
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(row.summary),
              if (row.citedEntryIds.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${row.citedEntryIds.length} cited moment(s)',
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ArchiveMobileTypography.sectionTitle(context)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Future<void> _exitCoachMode(BuildContext context) async {
    await _controller.switchToSelfReflection();
    if (!context.mounted) return;
    context.go(RouteCatalog.recordHome);
  }
}