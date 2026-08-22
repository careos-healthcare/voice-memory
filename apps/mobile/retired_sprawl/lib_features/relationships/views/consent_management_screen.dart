import 'dart:async';
import 'dart:convert';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/relationships/application/user_relationship_providers.dart';
import 'package:archiveme_mobile/features/relationships/relationship_copy.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/security/account_session_scope.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Client-side consent management for professional relationships.
class ConsentManagementScreen extends ConsumerStatefulWidget {
  const ConsentManagementScreen({super.key});

  @override
  ConsumerState<ConsentManagementScreen> createState() =>
      _ConsentManagementScreenState();
}

class _ConsentManagementScreenState
    extends ConsumerState<ConsentManagementScreen> {
  final _inviteController = TextEditingController();
  bool _shareFactLedger = false;
  bool _shareConfidenceInsights = true;

  String get _clientId {
    final session = AccountSessionRegistry.instance.current;
    return session.userId ?? session.namespace.key;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await ref.read(userRelationshipProvider.notifier).loadForClient(_clientId);
  }

  Map<String, dynamic> _currentScope() => {
        'factLedger': _shareFactLedger,
        'confidenceBandedInsights': _shareConfidenceInsights,
      };

  Future<void> _addConnection() async {
    final professionalId = _inviteController.text.trim();
    if (professionalId.isEmpty) return;

    final created = await ref
        .read(userRelationshipProvider.notifier)
        .requestProfessionalConnection(
          clientId: _clientId,
          professionalId: professionalId,
          scope: jsonEncode(_currentScope()),
        );

    if (!mounted) return;
    if (created != null) {
      _inviteController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection request saved locally.')),
      );
    }
  }

  Future<void> _revoke(UserRelationship relationship) async {
    await ref.read(userRelationshipProvider.notifier).updateConsentStatus(
          relationshipId: relationship.id,
          status: ConsentStatus.revoked,
          clientId: _clientId,
        );
  }

  Future<void> _activate(UserRelationship relationship) async {
    await ref.read(userRelationshipProvider.notifier).updateConsentStatus(
          relationshipId: relationship.id,
          status: ConsentStatus.active,
          clientId: _clientId,
        );
  }

  Future<void> _toggleScope(
    UserRelationship relationship, {
    required bool factLedger,
    required bool confidenceInsights,
  }) async {
    await ref.read(userRelationshipProvider.notifier).updateAgreedScope(
          relationshipId: relationship.id,
          agreedScope: {
            'factLedger': factLedger,
            'confidenceBandedInsights': confidenceInsights,
          },
          clientId: _clientId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userRelationshipProvider);

    return PushedScreenShell(
      title: RelationshipCopy.consentManagementTitle,
      showBottomDone: false,
      fallbackRoute: RouteCatalog.accountHome,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              RelationshipCopy.consentManagementIntro,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              RelationshipCopy.addConnectionTitle,
              style: ArchiveMobileTypography.responsiveBody(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _inviteController,
              decoration: const InputDecoration(
                hintText: RelationshipCopy.inviteCodeHint,
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share fact ledger labels'),
              value: _shareFactLedger,
              onChanged: (value) => setState(() => _shareFactLedger = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share confidence-banded insights'),
              value: _shareConfidenceInsights,
              onChanged: (value) =>
                  setState(() => _shareConfidenceInsights = value),
            ),
            FilledButton(
              onPressed: state.isLoading ? null : _addConnection,
              child: const Text(RelationshipCopy.addConnectionCta),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.errorMessage != null) ...[
              Text(
                state.errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (state.isLoading && state.clientRelationships.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (state.clientRelationships.isEmpty)
              _emptyCard(context)
            else
              ...state.clientRelationships.map(
                (relationship) => _relationshipCard(context, relationship),
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
              RelationshipCopy.noConnectionsTitle,
              style: ArchiveMobileTypography.responsiveBody(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              RelationshipCopy.noConnectionsBody,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _relationshipCard(
    BuildContext context,
    UserRelationship relationship,
  ) {
    final factLedger = relationship.agreedScope['factLedger'] == true;
    final confidence =
        relationship.agreedScope['confidenceBandedInsights'] != false;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              relationship.professionalId,
              style: ArchiveMobileTypography.responsiveBody(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              RelationshipCopy.relationshipStatusLabel(
                relationship.consentStatus.wireValue,
              ),
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fact ledger'),
              value: factLedger,
              onChanged: relationship.consentStatus == ConsentStatus.revoked
                  ? null
                  : (value) => _toggleScope(
                        relationship,
                        factLedger: value,
                        confidenceInsights: confidence,
                      ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Confidence insights'),
              value: confidence,
              onChanged: relationship.consentStatus == ConsentStatus.revoked
                  ? null
                  : (value) => _toggleScope(
                        relationship,
                        factLedger: factLedger,
                        confidenceInsights: value,
                      ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (relationship.consentStatus != ConsentStatus.active)
                  OutlinedButton(
                    onPressed: () => _activate(relationship),
                    child: const Text(RelationshipCopy.activateAccessCta),
                  ),
                TextButton(
                  onPressed: () => _revoke(relationship),
                  child: const Text(RelationshipCopy.revokeAccessCta),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}