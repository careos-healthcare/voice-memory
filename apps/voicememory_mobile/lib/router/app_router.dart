import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../billing/paywall_route_args.dart';
import '../billing/revenuecat_configuration.dart';
import '../features/archive_proof/archive_proof_record_routes.dart';
import '../record/quick_text_capture_presentation.dart';
import '../screens/about_screen.dart';
import '../screens/account_auth_screen.dart';
import '../screens/archive_belief_screen.dart';
import '../screens/archive_semantic_search_screen.dart';
import '../screens/belief_changes_screen.dart';
import '../screens/delete_account_screen.dart';
import '../screens/entry_detail_screen.dart';
import '../screens/export_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/paywall_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/quick_text_capture_screen.dart';
import '../screens/record_screen.dart';
import '../screens/recording_recovery_screen.dart';
import '../screens/restore_purchases_screen.dart';
import '../screens/security_settings_screen.dart';
import '../screens/support_feedback_screen.dart';
import '../screens/terms_screen.dart';
import '../widgets/account/privacy_trust_centre_screen.dart';
import '../widgets/main_shell.dart';
import '../screens/v1_account_screen.dart';
import '../screens/v1_settings_screen.dart';
import '../services/capture_pipeline_service.dart';
import '../core/config/v1_navigation_guard.dart';
import 'onboarding_gate.dart';
import 'onboarding_route_policy.dart';
import 'primary_destination.dart';
import 'primary_navigation_controller.dart';
import 'record_navigation_activity_controller.dart';
import 'route_catalog.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Root navigator for app-wide security and recovery prompts.
GlobalKey<NavigatorState> get appRootNavigatorKey => _rootNavigatorKey;

const instantCapturePaths = {RouteCatalog.quickTextCapture};

/// Only the V1 quick-capture link remains executable. All other historic
/// custom-scheme links are handled by the global V1 fallback.
String? resolveInstantCaptureDeepLink(Uri uri) {
  if (uri.scheme.toLowerCase() != 'archiveme') return null;
  final action = uri.host.isNotEmpty
      ? uri.host.toLowerCase()
      : uri.path.replaceFirst(RegExp(r'^/+'), '').toLowerCase();
  if (action != 'quick-capture') return RouteCatalog.recordHome;
  return Uri(
    path: RouteCatalog.quickTextCapture,
    queryParameters: {...uri.queryParameters, 'instant': '1'},
  ).toString();
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: RouteCatalog.recordHome,
  refreshListenable: onboardingGate,
  redirect: (context, state) {
    final deepLinkTarget = resolveInstantCaptureDeepLink(state.uri);
    if (deepLinkTarget != null) return deepLinkTarget;

    final path = state.uri.path;
    final v1Redirect = V1NavigationGuard.redirectFor(path);
    if (v1Redirect != null) return v1Redirect;

    final onboardingRedirect = OnboardingRoutePolicy.redirectBeforeCapture(
      path: path,
      onboardingComplete: onboardingGate.complete,
      screenshotMode: false,
      trialMode: false,
      isInstantCapture: instantCapturePaths.contains(path),
    );
    if (onboardingRedirect != null) return onboardingRedirect;
    if (path == '/') return RouteCatalog.recordHome;
    return null;
  },
  errorBuilder: (context, state) => const _SafeLegacyRouteRedirect(),
  routes: [
    GoRoute(path: '/', redirect: (_, _) => RouteCatalog.recordHome),
    GoRoute(
      path: RouteCatalog.onboarding,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const OnboardingScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) => MainShell(
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
              builder: (_, state) {
                final prompt = state.uri.queryParameters['prompt'];
                final guidedNode =
                    state.uri.queryParameters['guidedPromptNodeKey'];
                return RecordScreen(
                  initialPrompt:
                      prompt ??
                      ArchiveProofRecordRoutes.promptForGuidedNode(guidedNode),
                  autostartWithPrompt:
                      state.uri.queryParameters['autostart'] == '1',
                  navigationActivityController:
                      recordNavigationActivityController,
                  initialSavedResult: state.extra is CapturePipelineResult
                      ? state.extra! as CapturePipelineResult
                      : null,
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
              builder: (_, _) => const ArchiveBeliefScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: changesBranchNavigatorKey,
          routes: [
            GoRoute(
              path: RouteCatalog.changesHome,
              builder: (_, _) => const BeliefChangesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: accountBranchNavigatorKey,
          routes: [
            GoRoute(
              path: RouteCatalog.accountHome,
              builder: (_, _) => const V1AccountScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: RouteCatalog.quickTextCapture,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) {
        final extra = state.extra;
        final map = extra is Map ? extra : const <Object?, Object?>{};
        return QuickTextCaptureScreen(
          initialText: extra is String ? extra : map['initialText'] as String?,
          entryId: map['entryId'] as String?,
          queueJobId: map['queueJobId'] as String?,
          promptHint: map['prompt'] as String?,
          helperText: map['helper'] as String?,
          captureModeId: map['captureModeId'] as String?,
          allowQuietDaySave: map['allowQuietDaySave'] == true,
          showFirstUseWordingHelper:
              map['showFirstUseWordingHelper'] == true ||
              map['showGuidedExamples'] == true,
          focusedRecordTypeEntry: resolveFocusedRecordTypeEntry(extra),
          returnToRecordAfterSave:
              map['returnToRecordAfterSave'] == true ||
              state.uri.queryParameters['instant'] == '1',
        );
      },
    ),
    GoRoute(
      path: RouteCatalog.recordingRecovery,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const RecordingRecoveryScreen(),
    ),
    GoRoute(
      path: '/entry/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) =>
          EntryDetailScreen(entryId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/archive-search',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const ArchiveSemanticSearchScreen(),
    ),
    GoRoute(
      path: '/account/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) =>
          const AccountAuthScreen(intent: AccountAuthIntent.createAccount),
    ),
    GoRoute(
      path: '/account/sign-in',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) =>
          const AccountAuthScreen(intent: AccountAuthIntent.signIn),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const V1SettingsScreen(),
    ),
    GoRoute(
      path: '/security',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const SecuritySettingsScreen(),
    ),
    GoRoute(
      path: '/privacy-trust-centre',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const PrivacyTrustCentreScreen(),
    ),
    GoRoute(
      path: '/privacy',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const PrivacyScreen(),
    ),
    GoRoute(
      path: '/terms',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const TermsScreen(),
    ),
    GoRoute(
      path: '/about',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const AboutScreen(),
    ),
    GoRoute(
      path: '/support-feedback',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const SupportFeedbackScreen(),
    ),
    GoRoute(
      path: '/delete-account',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const DeleteAccountScreen(),
    ),
    GoRoute(
      path: '/export',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const ExportScreen(),
    ),
    if (RevenueCatConfiguration.purchasesEnabledAtBuildTime) ...[
      GoRoute(
        path: '/pricing',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const PricingScreen(),
      ),
      GoRoute(
        path: '/subscription',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => PaywallScreen(
          triggerArgs: state.extra is PaywallRouteArgs
              ? state.extra! as PaywallRouteArgs
              : null,
        ),
      ),
      GoRoute(
        path: '/restore-purchases',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const RestorePurchasesScreen(),
      ),
    ],
  ],
);

class _SafeLegacyRouteRedirect extends StatefulWidget {
  const _SafeLegacyRouteRedirect();

  @override
  State<_SafeLegacyRouteRedirect> createState() =>
      _SafeLegacyRouteRedirectState();
}

class _SafeLegacyRouteRedirectState extends State<_SafeLegacyRouteRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(RouteCatalog.archiveHome);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
