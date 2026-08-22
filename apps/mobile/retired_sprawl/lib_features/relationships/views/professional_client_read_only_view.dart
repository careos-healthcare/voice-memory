import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/coach/coach_mode_controller.dart';
import 'package:archiveme_mobile/features/coach/coach_read_service.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/relationships/relationship_copy.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';

/// Scoped read-only client view for a consenting professional relationship.
class ProfessionalClientReadOnlyView extends StatefulWidget {
  const ProfessionalClientReadOnlyView({
    required this.relationship, super.key,
    this.readService,
  });

  final UserRelationship relationship;
  final CoachReadService? readService;

  @override
  State<ProfessionalClientReadOnlyView> createState() =>
      _ProfessionalClientReadOnlyViewState();
}

class _ProfessionalClientReadOnlyViewState
    extends State<ProfessionalClientReadOnlyView> {
  CoachDashboardSnapshot? _snapshot;
  bool _loading = true;

  CoachReadService get _readService =>
      widget.readService ??
      CoachReadService(
        journalStore: AppServices.instance.journalStore,
        factLedgerStore: FactLedgerStore(AppServices.instance.prefs),
        modeController: CoachModeController.instance,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snapshot = await _readService.loadDashboardSnapshot();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _snapshot = snapshot;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: RelationshipCopy.readOnlyClientTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Client: ${widget.relationship.clientId}',
                  style: ArchiveMobileTypography.responsiveSectionTitle(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Scopes: ${widget.relationship.agreedScope}',
                  style: ArchiveMobileTypography.responsiveHelper(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_snapshot == null)
                  Text(
                    'No scoped data available without an active coach session.',
                    style: ArchiveMobileTypography.responsiveBody(context),
                  )
                else ...[
                  _section(context, 'Beliefs', _snapshot!.beliefs.length),
                  _section(context, 'Blind spots', _snapshot!.blindSpots.length),
                  _section(
                    context,
                    'Contradictions',
                    _snapshot!.contradictions.length,
                  ),
                  _section(
                    context,
                    'Fact ledger labels',
                    _snapshot!.factLedgerLabels.length,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _section(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Text(title),
        trailing: Text('$count'),
      ),
    );
  }
}