import 'package:archiveme_mobile/features/archive_theory/views/theories_screen.dart';
import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:archiveme_mobile/features/capture/screens/live_capture_host.dart';
import 'package:archiveme_mobile/features/sync/screens/offline_sync_verification_screen.dart';
import 'package:archiveme_mobile/config/production_navigation.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/features/auth/screens/guest_data_migration_screen.dart';
import 'package:archiveme_mobile/features/acquisition/acquisition_cohort_coordinator.dart';
import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/belief_evidence_trail.dart';
import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_demo_paths.dart';
import 'package:archiveme_mobile/features/referral/invite_attribution.dart';
import 'package:archiveme_mobile/router/capture_routine_route.dart';
import 'package:archiveme_mobile/router/developer_route_guard.dart';
import 'package:archiveme_mobile/router/archive_changes_deep_link.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:archiveme_mobile/router/primary_navigation_controller.dart';
import 'package:archiveme_mobile/router/record_navigation_activity_controller.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/router/v1_quarantine_redirects.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/features/settings/screens/about_screen.dart';
import 'package:archiveme_mobile/features/auth/screens/account_auth_screen.dart';
import 'package:archiveme_mobile/features/auth/screens/account_screen.dart';
import 'package:archiveme_mobile/features/archive/screens/archive_belief_screen.dart';
import 'package:archiveme_mobile/features/belief_evidence/screens/archive_evidence_context_screen.dart';
import 'package:archiveme_mobile/features/belief_changes/screens/belief_changes_screen.dart';
import 'package:archiveme_mobile/features/archive/screens/belief_detail_screen.dart';
import 'package:archiveme_mobile/features/belief_evidence/screens/belief_evidence_screen.dart';
import 'package:archiveme_mobile/features/archive/screens/beliefs_screen.dart';
import 'package:archiveme_mobile/features/auth/screens/delete_account_screen.dart';
import 'package:archiveme_mobile/features/archive/screens/entry_detail_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/consent_audit_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/export_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/journal_bulk_export_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/memory_transparency_screen.dart';
import 'package:archiveme_mobile/features/onboarding/screens/onboarding_screen.dart';
import 'package:archiveme_mobile/features/archive/screens/sample_archive_context_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/security_settings_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/privacy_security_screen.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_access_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/settings_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/support_feedback_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/terms_screen.dart';
import 'package:archiveme_mobile/features/settings/ui/privacy_trust_centre_screen.dart';
import 'package:archiveme_mobile/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Root navigator for app-wide prompts (offline vault recovery, etc.).
GlobalKey<NavigatorState> get appRootNavigatorKey => _rootNavigatorKey;

const instantCapturePaths = {'/quick-capture', '/quick-yes-capture'};

/// Converts custom-scheme widget and wearable launches into internal routes.
String? resolveInstantCaptureDeepLink(Uri uri) {
  if (uri.scheme.toLowerCase() != 'archiveme') return null;
  final action = uri.host.isNotEmpty
      ? uri.host.toLowerCase()
      : uri.path.replaceFirst(RegExp('^/+'), '').toLowerCase();
    final path = switch (action) {
    'record' => CaptureDeepLinkUris.recordLaunchRoute,
    'quick-capture' =>
      V1FeatureFlags.enableV1Only ? '/quick-capture' : '/quick-yes-capture',
    'voice-session' =>
      V1CapabilityRegistry.liveVoice ? '/live-voice' : RouteCatalog.recordHome,
    _ => null,
  };
  if (path == null) return null;
  final resolved = Uri.parse(path);
  return Uri(
    path: resolved.path,
    queryParameters: {
      ...resolved.queryParameters,
      ...uri.queryParameters,
      'instant': '1',
    },
  ).toString();
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: RouteCatalog.recordHome,
  refreshListenable: onboardingGate,
  redirect: (context, state) async {
    final instantCaptureTarget = resolveInstantCaptureDeepLink(state.uri);
    if (instantCaptureTarget != null) return instantCaptureTarget;

    final path = state.uri.path;

    final billingRedirect = V1RouteRegistry.billingCapabilityRedirect(path);
    if (billingRedirect != null) return billingRedirect;

    final v1Redirect = V1NavigationGuard.redirectFor(path);
    if (v1Redirect != null) return v1Redirect;

    final guarded = DeveloperRouteGuard.redirectFor(path);
    if (guarded != null) return guarded;

    final incompleteRedirect = ProductionNavigation.redirectAwayFromIncomplete(
      path,
    );
    if (incompleteRedirect != null) return incompleteRedirect;

    // Isolates an active caregiver session from the owner's app. Returns null
    // without touching storage while the capability is compiled out.
    final caregiverRedirect = await CaregiverModeController.tryRedirectFor(path);
    if (caregiverRedirect != null) return caregiverRedirect;

    if (path == '/start') {
      return AcquisitionCohortCoordinator.resolveStartRedirect(state.uri);
    }

    if (path == '/invite') {
      return InviteAttributionLink.resolveInviteRedirect(state.uri);
    }

    final cohortFastPath = await AcquisitionCohortCoordinator.fastPathRedirect(
      path,
    );
    if (cohortFastPath != null) return cohortFastPath;

    const onboardingPaths = {
      '/onboarding',
      '/onboarding-intent',
      '/onboarding-loop',
    };
    const startPaths = {
      '/start/capacity-yes',
      '/start/prove-enough',
      '/start/generic',
    };

    if (!ScreenshotMode.enabled &&
        !TrialMode.enabled &&
        !onboardingGate.complete &&
        !onboardingPaths.contains(path) &&
        !startPaths.contains(path) &&
        !instantCapturePaths.contains(path)) {
      return '/onboarding';
    }
    if (TrialMode.hideDeveloperSurfaces &&
        path != '/record' &&
        path != '/archive-belief' &&
        path != '/belief-changes' &&
        path != '/account' &&
        path != '/settings' &&
        path != '/about' &&
        path != '/privacy' &&
        path != '/privacy-trust-centre' &&
        path != '/terms' &&
        path != '/support-feedback' &&
        !path.startsWith('/entry/')) {
      if (path == '/onboarding') return '/record';
      if (DeveloperRouteGuard.redirectFor(path) != null ||
          ProductionNavigation.redirectAwayFromIncomplete(path) != null) {
        return '/record';
      }
    }
    if (path == '/') return RouteCatalog.recordHome;
    return null;
  },
  routes: [
    GoRoute(
      path: '/offline-sync-verify',
      builder: (context, state) => const OfflineSyncVerificationScreen(),
    ),
    GoRoute(path: '/', redirect: (context, state) => RouteCatalog.recordHome),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/onboarding-intent',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/onboarding',
    ),
    GoRoute(
      path: '/onboarding-loop',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/onboarding',
    ),
    GoRoute(
      path: '/start',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          AcquisitionCohortCoordinator.resolveStartRedirect(state.uri),
    ),
    GoRoute(
      path: '/invite',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          InviteAttributionLink.resolveInviteRedirect(state.uri),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MainShell(
        navigationShell: navigationShell,
        primaryNavigationController: primaryNavigationController,
        recordNavigationActivityController: recordNavigationActivityController,
      ),
      branches: [
        StatefulShellBranch(
          navigatorKey: recordBranchNavigatorKey,
          routes: [
            GoRoute(
              path: RouteCatalog.recordHome,
              builder: (context, state) {
                return LiveCaptureHost(
                  navigationActivityController:
                      recordNavigationActivityController,
                  routineKindOverride: journalRoutineKindFromUri(state.uri),
                  routeState: state,
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: archiveBranchNavigatorKey,
          routes: [
            GoRoute(
              path: RouteCatalog.archiveHome,
              builder: (context, state) => const ArchiveBeliefScreen(),
              routes: [
                GoRoute(
                  path: 'changes',
                  builder: (context, state) => const BeliefChangesScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: accountBranchNavigatorKey,
          routes: [
            GoRoute(
              path: RouteCatalog.accountHome,
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: RouteCatalog.changesHome,
      redirect: (context, state) => ArchiveChangesDeepLink.nestedChangesPath,
    ),
    GoRoute(
      path: '/security',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SecuritySettingsScreen(),
    ),
    GoRoute(
      path: '/privacy-security',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PrivacySecurityScreen(),
    ),
    GoRoute(
      path: '/caregiver-access',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CaregiverAccessScreen(),
    ),
    GoRoute(
      path: '/account/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          const AccountAuthScreen(intent: AccountAuthIntent.createAccount),
    ),
    GoRoute(
      path: '/account/sign-in',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          const AccountAuthScreen(intent: AccountAuthIntent.signIn),
    ),
    GoRoute(
      path: '/account/guest-data-migration',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const GuestDataMigrationScreen(),
    ),
    GoRoute(
      path: '/archive-debug',
      redirect: (context, state) => RouteCatalog.archiveHome,
    ),
    GoRoute(
      path: BeliefEvidenceNavigation.route,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BeliefEvidenceScreen(),
    ),
    GoRoute(
      path: ArchiveEvidenceMapNavigation.contextRoute,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => ArchiveEvidenceContextScreen(
        contextTagId: state.pathParameters['tagId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/quick-capture',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        String? initialText;
        String? entryId;
        if (extra is String) {
          initialText = extra;
        } else if (extra is Map) {
          initialText = extra['initialText'] as String?;
          entryId = extra['entryId'] as String?;
        }
        return LiveCaptureHost(
          typed: true,
          attachToEntryId: entryId,
          initialTypedText: initialText,
          routineKindOverride: journalRoutineKindFromUri(state.uri),
        );
      },
    ),
    GoRoute(
      path: '/entry/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          EntryDetailScreen(entryId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/theories',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TheoriesScreen(),
    ),
    GoRoute(
      path: '/belief-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! ArchiveBeliefCardModel) {
          return const BeliefsScreen();
        }
        return BeliefDetailScreen(belief: extra);
      },
    ),
    GoRoute(
      path: SampleArchiveDemoPaths.sampleContextRoute,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => SampleArchiveContextScreen(
        contextTagId: state.pathParameters['tagId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/export',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExportScreen(),
    ),
    GoRoute(
      path: '/journal-export',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const JournalBulkExportScreen(),
    ),
    GoRoute(
      path: '/memory-transparency',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MemoryTransparencyScreen(),
    ),
    GoRoute(
      path: '/consent-audit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConsentAuditScreen(),
    ),
    GoRoute(
      path: '/delete-account',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DeleteAccountScreen(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/support-feedback',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SupportFeedbackScreen(),
    ),
    GoRoute(
      path: '/about',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/privacy-trust-centre',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PrivacyTrustCentreScreen(),
    ),
    // `/privacy` redirects rather than retiring. Seven surfaces still push it
    // — About, the archive trust card, the account privacy controls, the
    // on-device hero, and the remote-processing consent step among them — and
    // two of those live under `lib/features/onboarding/`. A removed route
    // would turn each of those into a dead tap. `PrivacySummarySection`, the
    // body this route used to render, is now part of the trust centre, so the
    // redirect loses no content.
    GoRoute(
      path: '/privacy',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/privacy-trust-centre',
    ),
    GoRoute(
      path: '/terms',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TermsScreen(),
    ),
    if (V1FeatureFlags.enableV1Only)
      ...V1QuarantineRedirects.routes(rootNavigatorKey: _rootNavigatorKey),
  ],
);