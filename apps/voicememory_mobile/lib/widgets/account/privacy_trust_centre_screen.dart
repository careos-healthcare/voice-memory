import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/archive_export/archive_ownership_copy.dart';
import '../../features/archive_export/archive_privacy_summary.dart';

/// Focused V1 privacy centre.
///
/// Export, deletion, security, and legal actions each have one canonical route;
/// this screen does not construct backup, graph, beta, or analytics tooling.
class PrivacyTrustCentreScreen extends StatelessWidget {
  const PrivacyTrustCentreScreen({
    super.key,
    @Deprecated('Privacy controls are owned by their canonical routes')
    Object? controls,
    @Deprecated('Entitlement is irrelevant to user-owned privacy controls')
    Object? entitlementReader,
    @Deprecated('Behavioral-log export is not a V1 customer capability')
    Object? shareBehavioralLogExport,
    @Deprecated('Use the canonical export route') Object? openDataPortability,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy centre')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Your archive stays under your control',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Recordings and saved text are encrypted on this device. '
          'Remote transcription is used only after disclosure and consent. '
          'ArchiveMe does not sell access to your original moments.',
        ),
        const SizedBox(height: 12),
        for (final promise in ArchiveOwnershipCopy.all)
          Padding(
            key: Key('privacy_centre_promise_$promise'),
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(promise),
          ),
        const SizedBox(height: 16),
        Text(
          ArchivePrivacySummary.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        for (final fact in ArchivePrivacySummary.facts)
          _PrivacyFact(
            key: Key('privacy_centre_fact_${fact.title}'),
            icon: Icons.check_circle_outline,
            title: fact.title,
            body: fact.body,
          ),
        const Divider(height: 32),
        const _PrivacyFact(
          icon: Icons.mic_none,
          title: 'Remote transcription',
          body:
              'Audio selected for remote transcription is sent to the configured service. '
              'Cancelling keeps remote processing off.',
        ),
        const _PrivacyFact(
          icon: Icons.lock_outline,
          title: 'Protected originals',
          body:
              'Local journal data and audio vault files use the app’s protected storage boundaries.',
        ),
        const _PrivacyFact(
          icon: Icons.fact_check_outlined,
          title: 'Evidence and correction',
          body:
              'Interpretations link back to exact source moments and can be corrected or hidden.',
        ),
        const Divider(height: 32),
        const _RouteTile(
          icon: Icons.security_outlined,
          title: 'App lock and device privacy',
          route: '/security',
        ),
        const _RouteTile(
          icon: Icons.download_outlined,
          title: 'Export your archive',
          route: '/export',
        ),
        const _RouteTile(
          icon: Icons.delete_forever_outlined,
          title: 'Delete account and archive',
          route: '/delete-account',
        ),
        const _RouteTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          route: '/privacy',
        ),
        const _RouteTile(
          icon: Icons.description_outlined,
          title: 'Terms',
          route: '/terms',
        ),
      ],
    ),
  );
}

class _PrivacyFact extends StatelessWidget {
  const _PrivacyFact({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(body),
  );
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );
}
