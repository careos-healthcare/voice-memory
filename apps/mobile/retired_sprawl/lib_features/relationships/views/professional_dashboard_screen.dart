import 'dart:async';

import 'package:archiveme_mobile/billing/professional_coach_entitlement_gate.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/relationships/application/user_relationship_providers.dart';
import 'package:archiveme_mobile/features/relationships/relationship_copy.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:archiveme_mobile/features/relationships/views/professional_client_read_only_view.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/security/account_session_scope.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Professional dashboard — lists consenting clients behind per-seat billing.
class ProfessionalDashboardScreen extends ConsumerStatefulWidget {
  const ProfessionalDashboardScreen({super.key});

  @override
  ConsumerState<ProfessionalDashboardScreen> createState() =>
      _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState
    extends ConsumerState<ProfessionalDashboardScreen> {
  bool _checkingSeat = true;
  bool _hasSeat = false;

  String get _professionalId {
    final session = AccountSessionRegistry.instance.current;
    return session.userId ?? session.namespace.key;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final hasSeat = await ProfessionalCoachEntitlementGate.hasActiveProfessionalSeat();
    if (!mounted) return;
    setState(() {
      _checkingSeat = false;
      _hasSeat = hasSeat;
    });
    if (hasSeat) {
      await ref
          .read(userRelationshipProvider.notifier)
          .loadForProfessional(_professionalId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSeat) {
      return const PushedScreenShell(
        title: RelationshipCopy.professionalDashboardTitle,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasSeat) {
      return PushedScreenShell(
        title: RelationshipCopy.professionalDashboardTitle,
        showBottomDone: false,
        fallbackRoute: RouteCatalog.accountHome,
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    RelationshipCopy.perSeatRequiredTitle,
                    style: ArchiveMobileTypography.responsiveBody(context)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    RelationshipCopy.perSeatRequiredBody,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.push('/subscription'),
                    child: const Text('View professional plans'),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final state = ref.watch(userRelationshipProvider);

    return PushedScreenShell(
      title: RelationshipCopy.professionalDashboardTitle,
      showBottomDone: false,
      fallbackRoute: RouteCatalog.accountHome,
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              RelationshipCopy.professionalDashboardIntro,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.isLoading && state.professionalClients.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (state.professionalClients.isEmpty)
              _emptyCard(context)
            else
              ...state.professionalClients.map(
                (relationship) => _clientTile(context, relationship),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              RelationshipCopy.noClientsTitle,
              style: ArchiveMobileTypography.responsiveBody(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              RelationshipCopy.noClientsBody,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientTile(BuildContext context, UserRelationship relationship) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Text(relationship.clientId),
        subtitle: Text(
          RelationshipCopy.relationshipStatusLabel(
            relationship.consentStatus.wireValue,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfessionalClientReadOnlyView(
                  relationship: relationship,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}