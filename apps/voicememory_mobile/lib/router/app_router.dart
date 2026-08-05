import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/account_auth_screen.dart';
import '../screens/account_screen.dart';
import '../screens/security_settings_screen.dart';
import '../features/account_migration/guest_data_migration_screen.dart';
import '../screens/delete_account_screen.dart';
import '../screens/belief_changes_screen.dart';
import '../screens/belief_evidence_screen.dart';
import '../screens/weekly_archive_review_screen.dart';
import '../features/archive_beliefs/archive_belief_models.dart';
import '../screens/beliefs_screen.dart';
import '../screens/belief_detail_screen.dart';
import '../screens/weekly_story_screen.dart';
import '../screens/archive_explanation_screen.dart';
import '../features/archive_explanations/archive_explanation_navigation.dart';
import '../features/activation/belief_evidence_trail.dart';
import '../features/activation/weekly_archive_review.dart';
import '../features/activation/insight_quality_dashboard.dart';
import '../features/activation/archive_evidence_map.dart';
import '../screens/insight_quality_screen.dart';
import '../screens/archive_evidence_context_screen.dart';
import '../screens/entry_detail_screen.dart';
import '../screens/archive_export_screen.dart';
import '../screens/help_reviewer_guide_screen.dart';
import '../screens/testing_archiveme_screen.dart';
import '../screens/pro_value_preview_screen.dart';
import '../screens/support_feedback_screen.dart';
import '../screens/beta_feedback_screen.dart';
import '../screens/beta_outcomes_screen.dart';
import '../screens/beta_invite_pack_screen.dart';
import '../screens/first_week_path_screen.dart';
import '../screens/daily_archive_exercise_screen.dart';
import '../screens/archive_clarity_progress_screen.dart';
import '../screens/todays_one_question_screen.dart';
import '../screens/then_vs_now_screen.dart';
import '../screens/capacity_loop_screen.dart';
import '../screens/capacity_weekly_review_screen.dart';
import '../screens/capacity_boundary_response_screen.dart';
import '../screens/capacity_beta_signal_screen.dart';
import '../screens/low_effort_yes_capture_screen.dart';
import '../screens/capacity_beta_mission_screen.dart';
import '../screens/archive_calendar_screen.dart';
import '../screens/review_ritual_screen.dart';
import '../features/curiosity_loop/models/curiosity_hook.dart';
import '../features/curiosity_loop/presentation/yesterdays_snapshot_screen.dart';
import '../features/curiosity_loop/presentation/weekly_productivity_report_screen.dart';
import '../features/curiosity_loop/services/curiosity_notification_launch_controller.dart';
import '../features/curiosity_loop/yesterdays_snapshot_copy.dart';
import '../screens/milestone_share_cards_screen.dart';
import '../screens/pro_interest_screen.dart';
import '../features/demo/sample_archive_demo_paths.dart';
import '../screens/sample_archive_screen.dart';
import '../screens/sample_archive_context_screen.dart';
import '../screens/export_screen.dart';
import '../screens/collection_detail_screen.dart';
import '../screens/archive_pack_detail_screen.dart';
import '../screens/action_items_screen.dart';
import '../screens/fact_ledger_screen.dart';
import '../screens/archive_packs_screen.dart';
import '../screens/collections_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/pinned_evidence_screen.dart';
import '../screens/key_moments_screen.dart';
import '../screens/key_moment_detail_screen.dart';
import '../screens/archive_compression_screen.dart';
import '../screens/pattern_profile_screen.dart';
import '../screens/pattern_map_screen.dart';
import '../screens/archive_evolution_timeline_screen.dart';
import '../screens/archive_range_review_screen.dart';
import '../screens/ask_archive_screen.dart';
import '../features/moments/key_moment_model.dart';
import '../features/objective/objective_widget_pending_route_store.dart';
import '../screens/archive_belief_screen.dart';
import '../screens/archive_journey_screen.dart';
import '../screens/archive_share_discoveries_screen.dart';
import '../screens/archive_analyst_screen.dart';
import '../screens/archive_deep_dive_screen.dart';
import '../screens/archive_evidence_trail_screen.dart';
import '../features/archive_v1/archive_v1_models.dart';
import '../features/belief_evolution/belief_evolution_models.dart';
import '../features/archive_change_feed/archive_change_feed_models.dart';
import '../features/archive_surprises/archive_surprises_models.dart';
import '../features/belief_lifecycle/belief_lifecycle_models.dart';
import '../screens/archive_tool_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/loop_start_screen.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/referral/invite_attribution.dart';
import '../screens/loop_mode_screen.dart';
import '../screens/prove_enough_evidence_trail_screen.dart';
import '../screens/monthly_ambition_pressure_review_screen.dart';
import '../billing/paywall_route_args.dart';
import '../billing/revenuecat_configuration.dart';
import '../screens/paywall_screen.dart';
import '../screens/subscription_review_preview.dart';
import '../screens/pricing_screen.dart';
import '../screens/restore_purchases_screen.dart';
import '../screens/restore_production_verification_screen.dart';
import '../screens/signal_detail_screen.dart';
import '../screens/signal_evidence_screen.dart';
import '../screens/signal_journey_screen.dart';
import '../screens/signal_review_screen.dart';
import '../features/archive_proof/archive_proof_record_routes.dart';
import '../features/live_audio/application/live_voice_capture_service.dart';
import '../screens/live_voice_session_screen.dart';
import '../screens/record_screen.dart';
import '../screens/quick_text_capture_screen.dart';
import '../record/quick_text_capture_presentation.dart';
import '../screens/pressure_check_in_screen.dart';
import '../screens/pressure_insights_screen.dart';
// Timeline/Search screens unreachable — global redirect to Patterns.
import '../screens/native_push_verification_screen.dart';
import '../screens/revenuecat_verification_screen.dart';
import '../screens/offline_sync_verification_screen.dart';
import '../screens/about_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/developer_diagnostics_screen.dart';
import '../screens/first_pattern_quality_screen.dart';
import '../screens/trial_control_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/account/privacy_trust_centre_screen.dart';
import '../screens/updates_screen.dart';
import '../config/developer_settings_gate.dart';
import '../config/screenshot_mode.dart';
import '../config/trial_mode.dart';
import '../config/production_navigation.dart';
import '../core/config/v1_capability_registry.dart';
import '../core/config/v1_navigation_guard.dart';
import '../router/developer_route_guard.dart';
import '../router/primary_destination.dart';
import '../router/primary_navigation_controller.dart';
import '../router/record_navigation_activity_controller.dart';
import '../router/route_catalog.dart';
import '../widgets/main_shell.dart';
import 'onboarding_gate.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Root navigator for app-wide prompts (offline vault recovery, etc.).
GlobalKey<NavigatorState> get appRootNavigatorKey => _rootNavigatorKey;

bool _widgetLaunchRouteConsumed = false;
bool _curiosityNotificationLaunchConsumed = false;

const instantCapturePaths = {'/quick-yes-capture', '/live-voice'};

/// Converts custom-scheme widget and wearable launches into internal routes.
///
/// A two-slash URI such as `archiveme://quick-capture` stores the action in
/// [Uri.host], while a three-slash URI stores it in [Uri.path]. Both forms are
/// accepted so native launchers do not need platform-specific URL formatting.
String? resolveInstantCaptureDeepLink(Uri uri) {
  if (uri.scheme.toLowerCase() != 'archiveme') return null;
  final action = uri.host.isNotEmpty
      ? uri.host.toLowerCase()
      : uri.path.replaceFirst(RegExp(r'^/+'), '').toLowerCase();
  final path = switch (action) {
    'quick-capture' => '/quick-yes-capture',
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
        path != '/help-reviewer-guide' &&
        path != '/testing-archiveme' &&
        path != '/support-feedback' &&
        path != '/beta-feedback' &&
        path != '/first-week-path' &&
        path != '/daily-archive-exercise' &&
        path != '/archive-clarity-progress' &&
        path != '/todays-one-question' &&
        path != '/then-vs-now' &&
        path != '/capacity-loop' &&
        path != '/capacity-weekly-review' &&
        path != '/capacity-boundary-response' &&
        path != '/capacity-beta-signals' &&
        path != '/quick-yes-capture' &&
        path != '/live-voice' &&
        path != '/capacity-beta-mission' &&
        path != '/archive-calendar' &&
        path != '/review-ritual' &&
        path != '/yesterdays-snapshot' &&
        path != '/milestone-share-cards' &&
        path != '/beta-outcomes' &&
        path != '/beta-invite-pack' &&
        path != '/pro-interest' &&
        path != '/pro-preview' &&
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
    GoRoute(
      path: '/start/capacity-yes',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoopStartScreen(
        cohortId: AcquisitionCohortId.capacityYesDirect,
      ),
    ),
    GoRoute(
      path: '/start/prove-enough',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoopStartScreen(
        cohortId: AcquisitionCohortId.proveEnoughDirect,
      ),
    ),
    GoRoute(
      path: '/start/generic',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          const LoopStartScreen(cohortId: AcquisitionCohortId.genericArchive),
    ),
    GoRoute(
      path: '/loop-mode',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoopModeScreen(),
    ),
    GoRoute(
      path: '/prove-enough/evidence-trail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProveEnoughEvidenceTrailScreen(),
    ),
    GoRoute(
      path: '/prove-enough/monthly-review',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MonthlyAmbitionPressureReviewScreen(),
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
      redirect: (context, state) => DeveloperSettingsGate.isUnlocked
          ? '/developer-diagnostics'
          : '/archive-belief',
    ),
    GoRoute(
      path: BeliefEvidenceNavigation.route,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BeliefEvidenceScreen(),
    ),
    GoRoute(
      path: WeeklyArchiveReviewNavigation.route,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WeeklyArchiveReviewScreen(),
    ),
    GoRoute(
      path: InsightQualityNavigation.route,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const InsightQualityScreen(),
    ),
    GoRoute(
      path: ArchiveEvidenceMapNavigation.contextRoute,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => ArchiveEvidenceContextScreen(
        contextTagId: state.pathParameters['tagId'] ?? '',
      ),
    ),
    // Legacy aliases — global redirect handles locked developer paths.
    GoRoute(
      path: '/weekly-story',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WeeklyStoryScreen(),
    ),
    GoRoute(
      path: '/archive-explanation/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra;
        return ArchiveExplanationScreen(
          routeId: state.pathParameters['id'] ?? '',
          routeArgs: args is ArchiveExplanationRouteArgs ? args : null,
        );
      },
    ),
    GoRoute(
      path: '/archive-journey',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchiveJourneyScreen(),
    ),
    GoRoute(
      path: '/archive-share',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchiveShareDiscoveriesScreen(),
    ),
    GoRoute(
      path: '/archive-analyst',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchiveAnalystScreen(),
    ),
    GoRoute(
      path: '/archive-deep-dive',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! ArchiveV1View) {
          return ArchiveDeepDiveScreen(
            v1: ArchiveV1View(
              hasMinimumEvidence: false,
              belief: null,
              theory: null,
              theoryRanking: null,
              thenNow: null,
              contradictions: [],
              blindSpots: [],
              evolutionTimeline: const BeliefEvolutionTimeline(
                blocks: [],
                firstBelief: null,
                currentBelief: null,
              ),
              lifecycle: const BeliefLifecycleView(current: null, retired: []),
              changeFeed: ArchiveChangeFeedView.empty,
              surprises: ArchiveSurprisesView.empty,
              eligibleEntries: [],
            ),
          );
        }
        return ArchiveDeepDiveScreen(v1: extra);
      },
    ),
    GoRoute(
      path: '/archive-evidence-trail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! ArchiveV1View) {
          return ArchiveEvidenceTrailScreen(
            view: ArchiveV1View(
              hasMinimumEvidence: false,
              belief: null,
              theory: null,
              theoryRanking: null,
              thenNow: null,
              contradictions: [],
              blindSpots: [],
              evolutionTimeline: const BeliefEvolutionTimeline(
                blocks: [],
                firstBelief: null,
                currentBelief: null,
              ),
              lifecycle: const BeliefLifecycleView(current: null, retired: []),
              changeFeed: ArchiveChangeFeedView.empty,
              surprises: ArchiveSurprisesView.empty,
              eligibleEntries: [],
            ),
          );
        }
        return ArchiveEvidenceTrailScreen(view: extra);
      },
    ),
    GoRoute(
      path: '/archive-tool/:tool',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          ArchiveToolScreen(tool: state.pathParameters['tool'] ?? ''),
    ),
    if (V1CapabilityRegistry.liveVoice)
      GoRoute(
        path: '/live-voice',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          return LiveVoiceSessionScreen(
            liveVoiceCapture: extra is LiveVoiceCaptureService ? extra : null,
          );
        },
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
        bool allowQuietDaySave = false;
        bool showFirstUseWordingHelper = false;
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
      path: '/pressure-check-in',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PressureCheckInScreen(),
    ),
    GoRoute(
      path: '/pressure-insights',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PressureInsightsScreen(),
    ),
    GoRoute(
      path: '/journal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const JournalScreen(),
    ),
    GoRoute(
      path: '/pinned-evidence',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PinnedEvidenceScreen(),
    ),
    GoRoute(
      path: '/archive-packs',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchivePacksScreen(),
    ),
    GoRoute(
      path: '/archive-packs/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          ArchivePackDetailScreen(packId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/details',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FactLedgerScreen(),
    ),
    GoRoute(
      path: '/action-items',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ActionItemsScreen(),
    ),
    GoRoute(
      path: '/collections',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CollectionsScreen(),
    ),
    GoRoute(
      path: '/collections/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CollectionDetailScreen(
        collectionId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/moments',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const KeyMomentsScreen(),
    ),
    GoRoute(
      path: '/pattern-profile',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PatternProfileScreen(),
    ),
    GoRoute(
      path: '/archive-cleanup',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchiveCompressionScreen(),
    ),
    GoRoute(
      path: '/pattern-map',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PatternMapScreen(),
    ),
    GoRoute(
      path: '/archive-timeline',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchiveEvolutionTimelineScreen(),
    ),
    GoRoute(
      path: '/archive-review',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchiveRangeReviewScreen(),
    ),
    GoRoute(
      path: '/ask-archive',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AskArchiveScreen(),
    ),
    GoRoute(
      path: '/moment-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! KeyMoment) {
          return const KeyMomentsScreen();
        }
        return KeyMomentDetailScreen(moment: extra);
      },
    ),
    GoRoute(
      path: '/updates',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const UpdatesScreen(),
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
    if (RevenueCatConfiguration.purchasesEnabledAtBuildTime)
      GoRoute(
        path: '/subscription-review-preview',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SubscriptionReviewPreviewScreen(),
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
      path: '/signal-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SignalDetailScreen(),
    ),
    GoRoute(
      path: '/signal-evidence',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SignalEvidenceScreen(),
    ),
    GoRoute(
      path: '/signal-journey',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SignalJourneyScreen(),
    ),
    GoRoute(
      path: '/signal-review',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SignalReviewScreen(),
    ),
    if (RevenueCatConfiguration.purchasesEnabledAtBuildTime)
      GoRoute(
        path: '/restore-purchases',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RestorePurchasesScreen(),
      ),
    GoRoute(
      path: '/restore-production-verify',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RestoreProductionVerificationScreen(),
    ),
    GoRoute(
      path: '/archive-export',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchiveExportScreen(),
    ),
    GoRoute(
      path: '/sample-archive',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SampleArchiveScreen(),
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
      path: '/beta-feedback',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BetaFeedbackScreen(),
    ),
    GoRoute(
      path: '/first-week-path',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FirstWeekPathScreen(),
    ),
    GoRoute(
      path: '/daily-archive-exercise',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DailyArchiveExerciseScreen(),
    ),
    GoRoute(
      path: '/archive-clarity-progress',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchiveClarityProgressScreen(),
    ),
    GoRoute(
      path: '/todays-one-question',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TodaysOneQuestionScreen(),
    ),
    GoRoute(
      path: '/then-vs-now',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ThenVsNowScreen(),
    ),
    GoRoute(
      path: '/capacity-loop',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CapacityLoopScreen(),
    ),
    GoRoute(
      path: '/capacity-weekly-review',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CapacityWeeklyReviewScreen(),
    ),
    GoRoute(
      path: '/capacity-boundary-response',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CapacityBoundaryResponseScreen(),
    ),
    GoRoute(
      path: '/quick-yes-capture',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LowEffortYesCaptureScreen(),
    ),
    GoRoute(
      path: '/capacity-beta-mission',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CapacityBetaMissionScreen(),
    ),
    GoRoute(
      path: '/capacity-beta-signals',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CapacityBetaSignalScreen(),
    ),
    GoRoute(
      path: '/archive-calendar',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArchiveCalendarScreen(),
    ),
    GoRoute(
      path: '/review-ritual',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ReviewRitualScreen(),
    ),
    GoRoute(
      path: '/yesterdays-snapshot',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        if (state.extra is CuriosityHook) return null;
        if (CuriosityNotificationLaunchController.hasPendingHook) return null;
        return '/record';
      },
      builder: (context, state) {
        final hook = state.extra is CuriosityHook
            ? state.extra! as CuriosityHook
            : CuriosityNotificationLaunchController.takePendingHook();
        if (hook == null) {
          return const SizedBox.shrink();
        }
        return YesterdaysSnapshotScreen(hook: hook);
      },
    ),
    GoRoute(
      path: '/weekly-report',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WeeklyProductivityReportScreen(),
    ),
    GoRoute(
      path: '/milestone-share-cards',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MilestoneShareCardsScreen(),
    ),
    GoRoute(
      path: '/beta-outcomes',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BetaOutcomesScreen(),
    ),
    GoRoute(
      path: '/beta-invite-pack',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BetaInvitePackScreen(),
    ),
    GoRoute(
      path: '/help-reviewer-guide',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HelpReviewerGuideScreen(),
    ),
    GoRoute(
      path: '/testing-archiveme',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TestingArchiveMeScreen(),
    ),
    if (RevenueCatConfiguration.purchasesEnabledAtBuildTime)
      GoRoute(
        path: '/pro-preview',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProValuePreviewScreen(),
      ),
    GoRoute(
      path: '/pro-interest',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProInterestScreen(),
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
    GoRoute(
      path: '/developer-diagnostics',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DeveloperDiagnosticsScreen(),
    ),
    GoRoute(
      path: '/first-pattern-quality',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FirstPatternQualityScreen(),
    ),
    GoRoute(
      path: '/trial-control',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TrialControlScreen(),
    ),
    GoRoute(
      path: '/native-push-verify',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NativePushVerificationScreen(),
    ),
    GoRoute(
      path: '/revenuecat-verify',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RevenueCatVerificationScreen(),
    ),
    GoRoute(
      path: '/offline-sync-verify',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OfflineSyncVerificationScreen(),
    ),
  ],
);
