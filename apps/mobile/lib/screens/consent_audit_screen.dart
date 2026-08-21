import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_audit_service.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';

class ConsentAuditScreen extends StatefulWidget {
  const ConsentAuditScreen({super.key});

  @override
  State<ConsentAuditScreen> createState() => _ConsentAuditScreenState();
}

class _ConsentAuditScreenState extends State<ConsentAuditScreen> {
  List<ConsentGrantRecord> _grants = const [];
  List<AuditLogEntry> _accessLog = const [];
  bool _loading = true;

  ConsentAuditService? get _service {
    if (!AppServices.isInitialized) return null;
    return ConsentAuditService(prefs: AppServices.instance.prefs);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final service = _service;
    if (service == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final grants = await service.loadGrants();
    final log = await service.loadAccessLog();
    if (!mounted) return;
    setState(() {
      _grants = grants;
      _accessLog = log;
      _loading = false;
    });
  }

  Future<void> _revoke(ConsentGrantRecord record) async {
    await _service?.revokeGrant(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(ConsentAuditCopy.revokedSnack)),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: ConsentAuditCopy.title,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                Text(
                  ConsentAuditCopy.subtitle,
                  style: ArchiveMobileTypography.listSubtitle(context),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_grants.isEmpty)
                  Text(
                    ConsentAuditCopy.emptyGrants,
                    style: ArchiveMobileTypography.listSubtitle(context),
                  )
                else
                  for (final grant in _grants)
                    Card(
                      key: Key('consent_grant_${grant.tokenId}'),
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              ConsentAuditCopy.kindLabel(grant.kind),
                              style: ArchiveMobileTypography.listTitle(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${grant.granteeLabel} · '
                              '${ConsentAuditCopy.statusLabel(grant.status)}',
                              style: ArchiveMobileTypography.listSubtitle(context),
                            ),
                            Text(
                              'Granted ${ConsentAuditCopy.grantedLabel(grant.grantedAt)} · '
                              'Scope: ${grant.scopeSummary}',
                              style: ArchiveMobileTypography.listSubtitle(context),
                            ),
                            if (grant.status == ConsentGrantStatus.active)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  key: Key('consent_revoke_${grant.tokenId}'),
                                  onPressed: () => _revoke(grant),
                                  child: const Text(ConsentAuditCopy.revokeCta),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  ConsentAuditCopy.accessLogTitle,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  MemoryTransparencyCopy.accessLogFollowUp,
                  style: ArchiveMobileTypography.listSubtitle(context),
                ),
                Text(
                  ConsentAuditCopy.coachAccessLogFollowUp,
                  style: ArchiveMobileTypography.listSubtitle(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_accessLog.isEmpty)
                  Text(
                    'No local audit entries yet.',
                    style: ArchiveMobileTypography.listSubtitle(context),
                  )
                else
                  for (final entry in _accessLog.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        ConsentAuditCopy.auditLine(entry),
                        style: ArchiveMobileTypography.listSubtitle(context),
                      ),
                    ),
              ],
            ),
    );
  }
}
