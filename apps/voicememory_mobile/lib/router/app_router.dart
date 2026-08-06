import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/account_auth_screen.dart';
import '../screens/account_screen.dart';
import '../screens/security_settings_screen.dart';
import '../features/account_migration/guest_data_migration_screen.dart';
import '../screens/delete_account_screen.dart';
import '../screens/belief_changes_screen.dart';
import '../screens/belief_evidence_screen.dart';
import '../features/archive_beliefs/archive_belief_models.dart';
import '../screens/beliefs_screen.dart';
import '../screens/belief_detail_screen.dart';
import '../features/activation/belief_evidence_trail.dart';
import '../features/activation/archive_evidence_map.dart';
import '../screens/archive_evidence_context_screen.dart';
import '../screens/entry_detail_screen.dart';
import '../features/demo/sample_archive_demo_paths.dart';
import '../screens/sample_archive_context_screen.dart';
import '../billing/paywall_route_args.dart';
import '../billing/revenuecat_configuration.dart';
import '../screens/paywall_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/restore_purchases_screen.dart';
import '../features/archive_proof/archive_proof_record_routes.dart';
import '../screens/record_screen.dart';
import '../screens/quick_text_capture_screen.dart';
import '../record/quick_text_capture_presentation.dart';
import '../screens/about_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/account/privacy_trust_centre_screen.dart';
import '../screens/export_screen.dart';
import '../screens/support_feedback_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/archive_belief_screen.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/referral/invite_attribution.dart';
import '../features/objective/objective_widget_pending_route_store.dart';
import '../features/curiosity_loop/services/curiosity_notification_launch_controller.dart';
import '../features/curiosity_loop/yesterdays_snapshot_copy.dart';
import '../config/screenshot_mode.dart';
import '../config/screenshot_mode.dart';
import '../config/trial_mode.dart';
import '../config/production_navigation.dart';
import '../core/config/v1_capability_registry.dart';
import '../core/config/v1_feature_flags.dart';
import '../core/config/v1_navigation_guard.dart';
import '../router/developer_route_guard.dart';
import '../router/primary_destination.dart';
import '../router/primary_navigation_controller.dart';
import '../router/record_navigation_activity_controller.dart';
import '../router/route_catalog.dart';
import '../router/v1_quarantine_redirects.dart';
import '../widgets/main_shell.dart';
import 'onboarding_gate.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Root navigator for app-wide prompts (offline vault recovery, etc.).
GlobalKey<NavigatorState> get appRootNavigatorKey => _rootNavigatorKey;

bool _widgetLaunchRouteConsumed = false;
bool _curiosityNotificationLaunchConsumed = false;

const instantCapturePaths = {'/quick-capture', '/quick-yes-capture', '/live-voice'};

/// Converts custom-scheme widget and wearable launches into internal routes.
String? resolveInstantCaptureDeepLink(Uri uri) {
  if (uri.scheme.toLowerCase() != 'archiveme') return null;
  final action = uri.host.isNotEmpty
      ? uri.host.toLowerCase()
      : uri.path.replaceFirst(RegExp(r'^/+'), '').toLowerCase();
  final path = switch (action) {
    'quick-capture' => V1FeatureFlags.enableV1Only
        ? '/quick-capture'
        : '/quick-yes-capture',
    'voice-session' =>
      V1CapabilityRegistry.liveVoice ? '/live-voice' : RouteCatalog.recordHome,
    _ => null,
  };
  if (path == null) return null;
  return Uri(
    path: path,
    queryParameters: {...uri.queryParameters, 'instant': '1'},
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

    if (!_widgetLaunchRouteConsumed) {
      _widgetLaunchRouteConsumed = true;
      final pending = await ObjectiveWidgetPendingRouteStore.instance()
          .loadPendingRoute();
      if (pending != null && pending.isNotEmpty && path != pending) {
        await ObjectiveWidgetPendingRouteStore.instance().clear();
        return pending;
      }
    }

    if (!_curiosityNotificationLaunchConsumed) {
      _curiosityNotificationLaunchConsumed = true;
      if (CuriosityNotificationLaunchController.hasPendingHook &&
          path != YesterdaysSnapshotCopy.route &&
          V1NavigationGuard.isAllowed(YesterdaysSnapshotCopy.route)) {
        return YesterdaysSnapshotCopy.route;
      }
    }

    final v1Redirect = V1NavigationGuard.redirectFor(path);
    if (v1Redirect != null) return v1Redirect;

    final guarded = DeveloperRouteGuard.redirectFor(path);
    if (guarded != null) return guarded;

    final incompleteRedirect = ProductionNavigation.redirectAwayFromIncomplete(
      path,
    );
    if (incompleteRedirect != null) return incompleteRedirect;

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
                final prompt = state.uri.queryParameters['prompt'];
                final guidedNode =
                    state.uri.queryParameters['guidedPromptNodeKey'];
                final autostart = state.uri.queryParameters['autostart'] == '1';
                return RecordScreen(
                  initialPrompt:
                      prompt ??
                      ArchiveProofRecordRoutes.promptForGuidedNode(guidedNode),
                  autostartWithPrompt: autostart,
                  navigationActivityController:
                      recordNavigationActivityController,
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
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: changesBranchNavigatorKey,
          routes: [
            GoRoute(
              path: RouteCatalog.changesHome,
              builder: (context, state) => const BeliefChangesScreen(),
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
      path: '/security',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SecuritySettingsScreen(),
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
        String? promptHint;
        String? helperText;
        String? captureModeId;
        var allowQuietDaySave = false;
        var showFirstUseWordingHelper = false;
        final focusedRecordTypeEntry = resolveFocusedRecordTypeEntry(extra);
        if (extra is String) {
          initialText = extra;
        } else if (extra is Map) {
          initialText = extra['initialText'] as String?;
          entryId = extra['entryId'] as String?;
          promptHint = extra['prompt'] as String?;
          helperText = extra['helper'] as String?;
          captureModeId = extra['captureModeId'] as String?;
          allowQuietDaySave = extra['allowQuietDaySave'] == true;
          showFirstUseWordingHelper =
              extra['showFirstUseWordingHelper'] == true ||
              extra['showGuidedExamples'] == true;
        }
        return QuickTextCaptureScreen(
          initialText: initialText,
          entryId: entryId,
          promptHint: promptHint,
          helperText: helperText,
          captureModeId: captureModeId,
          allowQuietDaySave: allowQuietDaySave,
          showFirstUseWordingHelper: showFirstUseWordingHelper,
          focusedRecordTypeEntry: focusedRecordTypeEntry,
        );
      },
    ),
    GoRoute(
      path: '/entry/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          EntryDetailScreen(entryId: state.pathParameters['id'] ?? ''),
    ),
    if (RevenueCatConfiguration.purchasesEnabledAtBuildTime)
      GoRoute(
        path: '/pricing',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PricingScreen(),
      ),
    if (RevenueCatConfiguration.purchasesEnabledAtBuildTime)
      GoRoute(
        path: '/subscription',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          final args = extra is PaywallRouteArgs ? extra : null;
          return PaywallScreen(triggerArgs: args);
        },
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
    if (RevenueCatConfiguration.purchasesEnabledAtBuildTime)
      GoRoute(
        path: '/restore-purchases',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RestorePurchasesScreen(),
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
    GoRoute(
      path: '/privacy',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PrivacyScreen(),
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
