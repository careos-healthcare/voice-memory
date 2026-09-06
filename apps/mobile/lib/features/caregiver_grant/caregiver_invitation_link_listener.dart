import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Listens for incoming `https://archiveme.app/caregiver/*` Universal
/// Links / App Links and routes them to the (currently unregistered, see
/// route_catalog.dart) caregiver-consent entry screen.
///
/// Structured to mirror NetworkConnectivityNotifier exactly: a Notifier
/// holding a real StreamSubscription, a bind() method wiring up the
/// external source, ref.onDispose for cleanup.
class CaregiverInvitationLinkNotifier extends Notifier<void> {
  StreamSubscription<Uri>? _subscription;
  final AppLinks _appLinks = AppLinks();

  @override
  void build() {}

  void bind() {
    unawaited(_handleInitialLink());
    unawaited(_subscription?.cancel());
    _subscription = _appLinks.uriLinkStream.listen(_handleIncomingLink);
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      _subscription = null;
    });
  }

  Future<void> _handleInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) _handleIncomingLink(uri);
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.host != 'archiveme.app') return;
    if (!uri.path.startsWith('/caregiver')) return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    appRouter.go(
      Uri(
        path: RouteCatalog.caregiverConsent,
        queryParameters: {'token': token},
      ).toString(),
    );
  }
}

final caregiverInvitationLinkProvider =
    NotifierProvider<CaregiverInvitationLinkNotifier, void>(
      CaregiverInvitationLinkNotifier.new,
    );

/// Activates [CaregiverInvitationLinkNotifier] exactly once, on first
/// mount -- a ConsumerStatefulWidget's initState, not a plain ConsumerWidget's
/// build(), since bind() must run once, not on every rebuild.
class CaregiverInvitationLinkListenerHost extends ConsumerStatefulWidget {
  const CaregiverInvitationLinkListenerHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CaregiverInvitationLinkListenerHost> createState() =>
      _CaregiverInvitationLinkListenerHostState();
}

class _CaregiverInvitationLinkListenerHostState
    extends ConsumerState<CaregiverInvitationLinkListenerHost> {
  @override
  void initState() {
    super.initState();
    ref.read(caregiverInvitationLinkProvider.notifier).bind();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
