import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/developer_settings_gate.dart';
import '../config/trial_mode.dart';
import '../billing/revenuecat_service.dart';
import '../features/activation/activation_tracker.dart';
import '../features/activation/first_loop_activation_model.dart';
import '../features/pattern_memory/habit_proof_model.dart';
import '../features/pattern_memory/pattern_memory_model.dart';
import '../features/pattern_memory/pattern_next_action_model.dart';
import '../features/pattern_memory/pattern_progress_model.dart';
import '../features/pattern_memory/weekly_pattern_recap_model.dart';
import '../features/acquisition/acquisition_cohort_coordinator.dart';
import '../features/acquisition/acquisition_cohort_model.dart';
import '../features/acquisition/acquisition_intent_model.dart';
import '../features/acquisition/audience_wedge_model.dart';
import '../features/quality/first_insight_specificity_store.dart';
import '../features/trial/trial_reset_service.dart';
import '../features/trial/trial_summary_engine.dart';
import '../features/trial/trial_summary_exporter.dart';
import '../features/trial/hook_diagnosis_model.dart';
import '../features/trial/hook_rescue_decision_model.dart';
import '../features/trial/trial_summary_model.dart';
import '../widgets/trial/positioning_comprehension_sheet.dart';
import '../product/testflight_invite_copy.dart';
import '../theme/app_theme.dart';
import '../widgets/debug_only_unavailable.dart';

/// Facilitator screen for 5-user trial reset and export.
class TrialControlScreen extends StatefulWidget {
  const TrialControlScreen({super.key});

  @override
  State<TrialControlScreen> createState() => _TrialControlScreenState();
}

class _TrialControlScreenState extends State<TrialControlScreen> {
  final _participantController = TextEditingController();
  TrialSummaryModel? _summary;
  String? _jsonExport;
  String? _markdownExport;
  bool _loading = true;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    if (DeveloperSettingsGate.canShowDeveloperSettings) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _participantController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final summary = await const TrialSummaryEngine().build();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _participantController.text = summary.participantId ?? '';
      _jsonExport = const TrialSummaryExporter().toJson(summary);
      _markdownExport = const TrialSummaryExporter().toMarkdown(summary);
      _loading = false;
    });
  }

  Future<void> _saveParticipantId() async {
    await ActivationTracker.setParticipantId(_participantController.text);
    await _refresh();
  }

  Future<void> _resetParticipant() async {
    setState(() => _resetting = true);
    await const TrialResetService().resetForNewParticipant();
    _participantController.clear();
    await ActivationTracker.setParticipantId(null);
    await _refresh();
    if (!mounted) return;
    setState(() => _resetting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset for new participant')),
    );
  }

  Future<void> _assignCohort(AcquisitionCohortId cohortId) async {
    await AcquisitionCohortCoordinator.assignForTrial(cohortId);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cohort set: ${cohortId.id}')),
    );
  }

  Future<void> _clearCohort() async {
    await AcquisitionCohortCoordinator.clear();
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Acquisition cohort cleared')),
    );
  }

  Future<void> _copyInvite(TestFlightInviteVariant variant) async {
    final text = TestFlightInviteCopy.clipboardPack(variant);
    await Clipboard.setData(ClipboardData(text: text));
    switch (variant) {
      case TestFlightInviteVariant.capacityYes:
        ActivationTracker.trackCapacityInviteCopied();
      case TestFlightInviteVariant.proveEnough:
        ActivationTracker.trackProveInviteCopied();
      case TestFlightInviteVariant.generic:
        ActivationTracker.trackGenericInviteCopied();
    }
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${variant.id} invite copied')),
    );
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    await ActivationTracker.trackTrialExportCopied();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const DebugOnlyUnavailableScreen(title: 'Trial control');
    }

    final summary = _summary;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Trial control'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Trial mode', TrialMode.enabled ? 'enabled' : 'disabled'),
          const SizedBox(height: 8),
          Text(
            'Compile with --dart-define=ARCHIVEME_TRIAL_MODE=true',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(
            'RevenueCat diagnostics',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ..._revenueCatDiagnosticRows(),
          const SizedBox(height: 24),
          TextField(
            controller: _participantController,
            decoration: const InputDecoration(
              labelText: 'Participant ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveParticipantId,
            child: const Text('Save participant ID'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _resetting ? null : _resetParticipant,
            child: _resetting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reset for new participant'),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (summary != null) ...[
            Text(
              'Hook verdict: ${summary.verdict.id}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Friction: ${summary.trialFrictionVerdict.id}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Hook diagnosis: ${summary.hookDiagnosis.likelyFailure}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            ..._metricRows(summary),
            const SizedBox(height: 16),
            Text(
              'Positioning comprehension',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._positioningComprehensionRows(summary),
            OutlinedButton(
              onPressed: () => PositioningComprehensionSheet.show(context),
              child: const Text('Ask positioning question'),
            ),
            const SizedBox(height: 8),
            Text(
              'Hook diagnosis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._hookDiagnosisRows(summary.hookDiagnosis),
            const SizedBox(height: 16),
            Text(
              'Reminder readiness',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._reminderReadinessRows(summary),
            const SizedBox(height: 16),
            Text(
              'Recommended next fix',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._recommendedFixRows(summary),
            const SizedBox(height: 16),
            Text(
              'Hook escalation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._hookEscalationRows(summary),
            const SizedBox(height: 16),
            Text(
              'Archive feedback',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._archiveFeedbackRows(summary),
            const SizedBox(height: 16),
            Text(
              'Archive compression',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._archiveCompressionRows(summary),
            const SizedBox(height: 16),
            Text(
              'Memory quality',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._memoryQualityRows(summary),
            const SizedBox(height: 16),
            Text(
              'Acquisition cohort',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._acquisitionCohortRows(summary),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _assignCohort(
                    AcquisitionCohortId.capacityYesDirect,
                  ),
                  child: const Text('capacity_yes_direct'),
                ),
                OutlinedButton(
                  onPressed: () => _assignCohort(
                    AcquisitionCohortId.proveEnoughDirect,
                  ),
                  child: const Text('prove_enough_direct'),
                ),
                OutlinedButton(
                  onPressed: () => _assignCohort(
                    AcquisitionCohortId.genericArchive,
                  ),
                  child: const Text('generic_archive'),
                ),
                OutlinedButton(
                  onPressed: _clearCohort,
                  child: const Text('Clear cohort'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tester invite copy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._testerInviteRows(summary),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _copyInvite(
                    TestFlightInviteVariant.capacityYes,
                  ),
                  child: const Text('Copy capacity invite'),
                ),
                OutlinedButton(
                  onPressed: () => _copyInvite(
                    TestFlightInviteVariant.proveEnough,
                  ),
                  child: const Text('Copy proving-enough invite'),
                ),
                OutlinedButton(
                  onPressed: () => _copyInvite(
                    TestFlightInviteVariant.generic,
                  ),
                  child: const Text('Copy generic invite'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              TestFlightInviteCopy.shortText(
                TestFlightInviteVariant.proveEnough,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Retention diagnosis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._retentionDiagnosisRows(summary),
            const SizedBox(height: 16),
            Text(
              'Billing / paywall',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._billingRows(summary),
            const SizedBox(height: 16),
            Text(
              'Archive range review',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._archiveRangeReviewRows(summary),
            const SizedBox(height: 16),
            Text(
              'Retention loop',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._retentionRows(summary),
            const SizedBox(height: 16),
            Text(
              'Compelling check',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._compellingCheckRows(summary),
            const SizedBox(height: 16),
            Text(
              'Real reminders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._realReminderRows(summary),
            const SizedBox(height: 16),
            Text(
              'Current objective',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._currentObjectiveRows(summary),
            const SizedBox(height: 16),
            Text(
              'Pro value preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._proValuePreviewRows(summary),
            const SizedBox(height: 16),
            Text(
              'Today\u2019s check widget',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._objectiveWidgetRows(summary),
            const SizedBox(height: 16),
            Text(
              'Pattern memory',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._patternMemoryRows(summary),
            const SizedBox(height: 16),
            Text(
              'Pattern progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._patternProgressRows(summary),
            const SizedBox(height: 16),
            Text(
              'Pattern next action',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._patternNextActionRows(summary),
            const SizedBox(height: 16),
            Text(
              'Habit proof',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._habitProofRows(summary),
            const SizedBox(height: 16),
            Text(
              'Weekly pattern recap',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._weeklyPatternRecapRows(summary),
            const SizedBox(height: 16),
            Text(
              'Pattern share',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._patternShareRows(summary),
            const SizedBox(height: 16),
            Text(
              'Activation loop',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._activationLoopRows(summary),
            const SizedBox(height: 16),
            Text(
              'First loop',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._firstLoopRows(summary),
            const SizedBox(height: 16),
            Text(
              'Return day',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._returnDayRows(summary),
            const SizedBox(height: 16),
            if (_jsonExport != null) ...[
              FilledButton(
                onPressed: () => _copy(_jsonExport!, 'JSON'),
                child: const Text('Copy JSON export'),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _jsonExport!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (_markdownExport != null) ...[
              FilledButton(
                onPressed: () => _copy(_markdownExport!, 'Markdown'),
                child: const Text('Copy Markdown export'),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _markdownExport!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _metricRows(TrialSummaryModel s) {
    String pct(double? v) =>
        v == null ? '—' : '${(v * 100).toStringAsFixed(0)}%';
    return [
      _row('First reflection saved', '${s.firstReflectionSaved}'),
      _row('First pattern shown', '${s.firstPatternShown}'),
      _row('First pattern accepted', '${s.firstPatternAccepted}'),
      _row('First pattern corrected', '${s.firstPatternCorrected}'),
      _row('Watch-for shown', '${s.watchForPromptShown}'),
      _row('Watch-for accepted', '${s.watchForPromptAccepted}'),
      _row('Quick answer selected', '${s.returnCaptureQuickAnswerSelected}'),
      _row('Returned next day', '${s.returnedNextDay}'),
      _row('Second reflection saved', '${s.secondReflectionSaved}'),
      _row('Comparison viewed', '${s.comparisonViewed}'),
      _row('Useful — yes', '${s.usefulnessYes}'),
      _row('Useful — sort of', '${s.usefulnessSortOf}'),
      _row('Useful — not really', '${s.usefulnessNotReally}'),
      _row('Third reflection saved', '${s.thirdReflectionSaved}'),
      _row('Correction rate', pct(s.correctionRate)),
      _row('Watch-for accept rate', pct(s.watchForAcceptRate)),
      _row('Day-2 return rate', pct(s.day2ReturnRate)),
      _row('Useful rate', pct(s.usefulRate)),
      const Divider(height: 24),
      _row('App opened', '${s.appOpenedCount}'),
      _row('Record CTA tapped', '${s.recordCtaTappedCount}'),
      _row('Recording started', '${s.recordingStartedCount}'),
      _row('Reflections saved', '${s.recordingSavedCount}'),
      _row('Mic denied', '${s.micDeniedCount}'),
      _row('Save completed', '${s.saveCompletedCount}'),
      _row('Closed before watch-for', '${s.closedBeforeWatchForAcceptedCount}'),
      const Divider(height: 24),
      _row('Check-in created', '${s.checkInCreatedCount}'),
      _row('Check-in due shown', '${s.checkInDueShownCount}'),
      _row('Check-in option selected', '${s.checkInOptionSelectedCount}'),
      _row('Check-in completed', '${s.checkInCompletedCount}'),
      _row('Check-in completion rate', pct(s.checkInCompletionRate)),
    ];
  }

  List<Widget> _hookDiagnosisRows(HookDiagnosisSummary d) {
    return [
      _row('Likely failure', d.likelyFailure),
      _row('Question — useful', '${d.checkInQuestionRatedUseful}'),
      _row('Question — sort of', '${d.checkInQuestionRatedSortOf}'),
      _row('Question — not useful', '${d.checkInQuestionRatedNotUseful}'),
      _row('Missed — forgot', '${d.forgotCount}'),
      _row('Missed — did not care', '${d.didNotCareCount}'),
      _row('Missed — confusing', '${d.confusingCount}'),
      _row('Result — useful', '${d.resultUsefulCount}'),
      _row('Result — sort of', '${d.resultSortOfCount}'),
      _row('Result — not useful', '${d.resultNotUsefulCount}'),
      _row('Examples opened', '${d.examplesOpenedCount}'),
      _row('Clarity card shown', '${d.checkInClarityCardShownCount}'),
      _row('Moment recorded CTA', '${d.checkInMomentRecordedCount}'),
      _row(
        'Clarity issue rate',
        d.clarityIssueRate == null
            ? '—'
            : '${(d.clarityIssueRate! * 100).toStringAsFixed(0)}%',
      ),
      _row(
        'Not useful — too vague',
        '${d.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.tooVague] ?? 0}',
      ),
      _row(
        'Not useful — not accurate',
        '${d.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.notAccurate] ?? 0}',
      ),
      _row(
        'Not useful — already knew',
        '${d.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.alreadyKnewThis] ?? 0}',
      ),
      _row(
        'Not useful — confusing',
        '${d.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.confusing] ?? 0}',
      ),
    ];
  }

  List<Widget> _reminderReadinessRows(TrialSummaryModel s) {
    final label = switch (s.reminderReadiness) {
      ReminderReadiness.ready => 'Ready',
      ReminderReadiness.maybe => 'Maybe',
      ReminderReadiness.notReady => 'Not ready',
    };
    return [
      _row('Status', label),
      _row('Reason', s.reminderReadinessReason),
      _row('Reminder candidates', '${s.reminderCandidateCount}'),
      _row('Reminders enabled', s.reminderEnabled ? 'On' : 'Off'),
      _row('Permission requested', '${s.reminderPermissionRequestedCount}'),
      _row('Permission granted', '${s.reminderPermissionGrantedCount}'),
      _row('Permission denied', '${s.reminderPermissionDeniedCount}'),
      _row('Reminder cancelled', '${s.reminderCancelledCount}'),
      _row('Reminder tapped', '${s.reminderTappedCount}'),
    ];
  }

  List<Widget> _recommendedFixRows(TrialSummaryModel s) {
    String label(HookRescueAction a) {
      switch (a) {
        case HookRescueAction.none:
          return 'None';
        case HookRescueAction.reminder:
          return 'Reminder';
        case HookRescueAction.guidedCheckIn:
          return 'Guided check-in';
        case HookRescueAction.sharperQuestion:
          return 'Sharper question';
        case HookRescueAction.betterResult:
          return 'Better result';
        case HookRescueAction.betterFirstRecord:
          return 'Better first record';
      }
    }

    final secondary = s.hookRescueSecondaryActions.isEmpty
        ? '—'
        : s.hookRescueSecondaryActions.map(label).join(', ');
    return [
      _row('Primary action', label(s.hookRescuePrimaryAction)),
      _row('Reason', s.hookRescueReason),
      _row('Secondary actions', secondary),
      _row('Confidence', s.hookRescueConfidence.id),
    ];
  }

  List<Widget> _hookEscalationRows(TrialSummaryModel s) {
    String reminderLabel(ReminderImplementationStatus status) {
      switch (status) {
        case ReminderImplementationStatus.noOp:
          return 'no-op';
        case ReminderImplementationStatus.available:
          return 'available';
        case ReminderImplementationStatus.permissionDenied:
          return 'permission denied';
        case ReminderImplementationStatus.scheduled:
          return 'scheduled';
      }
    }

    return [
      _row('Sharper question', s.sharperQuestionIntensity.id),
      _row('Better result', s.betterResultIntensity.id),
      _row('Sharper shown / accepted',
          '${s.sharperQuestionGeneratedCount} / ${s.sharperQuestionAcceptedCount}'),
      _row('Very sharp shown / accepted',
          '${s.verySharpQuestionGeneratedCount} / ${s.verySharpQuestionAcceptedCount}'),
      _row('Better result shown / aggressive',
          '${s.betterResultShownCount} / ${s.aggressiveBetterResultShownCount}'),
      _row('Go deeper shown / opened',
          '${s.checkInGoDeeperShownCount} / ${s.checkInGoDeeperTappedCount}'),
      _row('Next check shown / used',
          '${s.resultNextCheckShownCount} / ${s.resultNextCheckUsedCount}'),
      _row('Next check changed / from patterns',
          '${s.resultNextCheckChangedCount} / ${s.resultNextCheckUsedFromPatternsCount}'),
      _row('Useful takeaway shown', '${s.usefulResultTakeawayShownCount}'),
      _row('Make more useful tapped / reason',
          '${s.makeResultMoreUsefulTappedCount} / ${s.makeResultMoreUsefulReasonSelectedCount}'),
      _row('Useful next check used', '${s.usefulResultNextCheckUsedCount}'),
      _row('Input quality coach shown', '${s.inputQualityCoachShownCount}'),
      _row('Sentence added / used anyway',
          '${s.inputQualitySentenceAddedCount} / ${s.inputQualityUsedAnywayCount}'),
      _row('Accepted weak / sharpened',
          '${s.acceptedWeakInputCount} / ${s.sharpenedInputCount}'),
      _row('Latest input level',
          s.latestInputQualityLevel ?? 'none'),
      _row('Avg input score',
          s.averageInputQualityScore?.toStringAsFixed(2) ?? 'n/a'),
      _row('Perspective shown / used',
          '${s.perspectiveShiftShownCount} / ${s.perspectiveShiftUsedCount}'),
      _row('Perspective changed', '${s.perspectiveShiftChangedCount}'),
      _row('Perspective patterns shown / used',
          '${s.perspectiveShiftShownFromPatternsCount} / ${s.perspectiveShiftUsedFromPatternsCount}'),
      _row('Kinder angle shown / used',
          '${s.kinderAngleShownCount} / ${s.kinderAngleUsedCount}'),
      _row('Kinder angle changed', '${s.kinderAngleChangedCount}'),
      _row('Kinder angle patterns shown / used',
          '${s.kinderAngleShownFromPatternsCount} / ${s.kinderAngleUsedFromPatternsCount}'),
      _row('Quick help opened / intent',
          '${s.quickHelpOpenedCount} / ${s.quickHelpIntentSelectedCount}'),
      _row('Quick help action / check used',
          '${s.quickHelpPrimaryActionTappedCount} / ${s.quickHelpCheckUsedCount}'),
      _row('Key moments created / opened',
          '${s.keyMomentCreatedCount} / ${s.keyMomentOpenedCount}'),
      _row('Key moments search / use check',
          '${s.keyMomentSearchUsedCount} / ${s.keyMomentUseCheckTappedCount}'),
      _row('Ask archive opened / search',
          '${s.askArchiveOpenedCount} / ${s.askArchiveSearchUsedCount}'),
      _row('Ask archive chip / result opened',
          '${s.askArchiveSuggestedChipTappedCount} / ${s.askArchiveResultOpenedCount}'),
      _row('Ask archive use check', '${s.askArchiveUseCheckTappedCount}'),
      _row('Archive clean shown / tapped',
          '${s.archiveCleanViewShownCount} / ${s.archiveCleanSectionTappedCount}'),
      _row('Pattern profile shown / opened',
          '${s.patternProfileShownCount} / ${s.patternProfileOpenedCount}'),
      _row('Pattern profile use check / find moments',
          '${s.patternProfileUseCheckTappedCount} / ${s.patternProfileFindMomentsTappedCount}'),
      _row('Pattern profile open timeline',
          '${s.patternProfileOpenTimelineTappedCount}'),
      _row('Pattern map shown / opened',
          '${s.patternMapShownCount} / ${s.patternMapOpenedCount}'),
      _row('Pattern map use check',
          '${s.patternMapUseCheckTappedCount}'),
      _row('Archive memory shown', '${s.archiveMemorySummaryShownCount}'),
      _row('Archive memory map / moments',
          '${s.archiveMemoryOpenPatternMapTappedCount} / ${s.archiveMemoryFindMomentsTappedCount}'),
      _row('Archive memory use check',
          '${s.archiveMemoryUseCheckTappedCount}'),
      _row('Timeline shown / opened',
          '${s.archiveTimelineShownCount} / ${s.archiveTimelineOpenedCount}'),
      _row('Timeline use check', '${s.archiveTimelineUseCheckTappedCount}'),
      _row('Reminder', reminderLabel(s.reminderImplementationStatus)),
      _row('Reminder scheduled', '${s.reminderScheduledCount}'),
      _row('Reminder denied', '${s.reminderDeniedCount}'),
    ];
  }

  List<Widget> _archiveFeedbackRows(TrialSummaryModel s) {
    return [
      _row('Shown', '${s.archiveFeedbackShownCount}'),
      _row('Selected', '${s.archiveFeedbackSelectedCount}'),
      _row('Useful', '${s.archiveFeedbackUsefulCount}'),
      _row('Too generic', '${s.archiveFeedbackTooGenericCount}'),
      _row('Not me', '${s.archiveFeedbackNotMeCount}'),
      _row('Already knew', '${s.archiveFeedbackAlreadyKnewCount}'),
      _row('More specific', '${s.archiveFeedbackMoreSpecificCount}'),
      _row('Dominant issue', s.archiveFeedbackDominantIssue),
    ];
  }

  List<Widget> _archiveCompressionRows(TrialSummaryModel s) {
    return [
      _row('Shown', '${s.archiveCompressionShownCount}'),
      _row('Opened', '${s.archiveCompressionOpenedCount}'),
      _row('Kept', '${s.archiveCompressionKeptCount}'),
      _row('Split', '${s.archiveCompressionSplitCount}'),
      _row('Hidden', '${s.archiveCompressionHiddenCount}'),
    ];
  }

  List<Widget> _memoryQualityRows(TrialSummaryModel s) {
    return [
      _row('Shown', '${s.memoryQualityShownCount}'),
      _row('Tapped', '${s.memoryQualityTappedCount}'),
      _row('Latest level', s.latestMemoryQualityLevel ?? 'none'),
    ];
  }

  List<Widget> _testerInviteRows(TrialSummaryModel s) {
    return [
      _row('Capacity invite copied', '${s.capacityInviteCopiedCount}'),
      _row('Prove invite copied', '${s.proveInviteCopiedCount}'),
      _row('Generic invite copied', '${s.genericInviteCopiedCount}'),
      _row('Prove default shown', '${s.proveDefaultShownCount}'),
      _row('Prove default started', '${s.proveDefaultStartedCount}'),
      _row('Prove first moment', '${s.proveFirstMomentRecordedCount}'),
      _row('Prove read accepted', '${s.proveReadAcceptedCount}'),
      _row('Prove second moment', '${s.proveSecondMomentRecordedCount}'),
      _row('Prove review confirmed', '${s.proveReviewConfirmedCount}'),
      _row('Prove pro teaser tapped', '${s.provePaywallTeaserTappedCount}'),
      _row(
        'Primary route',
        TestFlightInviteCopy.cohortRouteFor(
          TestFlightInviteVariant.proveEnough,
        ),
      ),
    ];
  }

  List<Widget> _acquisitionCohortRows(TrialSummaryModel s) {
    final c = s.acquisitionCohort;
    if (c == null) {
      return [_row('Cohort', 'none')];
    }
    return [
      _row('Cohort', c.cohortId.label),
      _row('Source', c.source.isNotEmpty ? c.source : '—'),
      _row('Loop promise shown', c.promiseShown.isNotEmpty ? c.promiseShown : '—'),
      _row('First moment recorded', c.firstMomentRecorded ? 'yes' : 'no'),
      _row('Second moment recorded', c.secondMomentRecorded ? 'yes' : 'no'),
      _row('Third moment recorded', c.thirdMomentRecorded ? 'yes' : 'no'),
      _row('Review reached', c.loopReviewReached ? 'yes' : 'no'),
      _row('Review confirmed', c.loopReviewConfirmed ? 'yes' : 'no'),
      _row('Pro teaser tapped', c.paywallTeaserTapped ? 'yes' : 'no'),
    ];
  }

  List<Widget> _retentionDiagnosisRows(TrialSummaryModel s) {
    final d = s.retentionDiagnosisSnapshot;
    if (d == null) {
      return [_row('Status', 'Not computed')];
    }
    return [
      _row('Bottleneck', d.retentionBottleneckLabel),
      _row('Summary', d.retentionBottleneckSummary),
      _row('Onboarding intent', d.onboardingIntent?.label ?? 'none'),
      _row('Audience wedge', d.audienceWedgeSelected?.label ?? 'none'),
      _row(
        'First insight specificity',
        d.firstInsightSpecificityRating?.id ?? 'none',
      ),
      _row('Wedge read matched', d.wedgeInterpretationMatched ? 'yes' : 'no'),
      _row('First prompt used', d.firstPromptUsed ? 'yes' : 'no'),
      _row('Read useful', '${d.readUsefulTappedCount}'),
      _row('Read not quite', '${d.readNotQuiteTappedCount}'),
      _row('Interpretation strong', '${d.interpretationStrongCount}'),
      _row('Interpretation weak', '${d.interpretationWeakCount}'),
      _row('Reminder timing offered', '${d.reminderTimingOfferedCount}'),
      _row('Reminder timing selected', '${d.reminderTimingSelectedCount}'),
      _row('Reminder dismissed', '${d.reminderPrePromptDismissedCount}'),
      _row('Reminder return', '${d.reminderReturnRecordedCount}'),
      _row('Loop review viewed', d.loopReviewViewed ? 'yes' : 'no'),
      _row('Loop review confirmed', d.loopReviewConfirmed ? 'yes' : 'no'),
      _row('Loop review corrected', d.loopReviewCorrected ? 'yes' : 'no'),
      _row('Loop review kept watching', d.loopReviewKeptWatching ? 'yes' : 'no'),
      _row('Loop paywall teaser shown', d.loopPaywallTeaserShown ? 'yes' : 'no'),
      _row('Loop paywall teaser tapped', d.loopPaywallTeaserTapped ? 'yes' : 'no'),
      _row('Prove enough selected', d.proveEnoughSelected ? 'yes' : 'no'),
      _row('Prove enough first prompt', d.proveEnoughFirstPromptUsed ? 'yes' : 'no'),
      _row('Prove enough matched recording', d.proveEnoughMatchedFirstRecording ? 'yes' : 'no'),
      _row('Prove enough read accepted', d.proveEnoughReadAccepted ? 'yes' : 'no'),
      _row('Prove enough unsupported', d.proveEnoughUnsupportedRecording ? 'yes' : 'no'),
      _row('Prove enough completed', d.proveEnoughCompleted ? 'yes' : 'no'),
      _row(
        'Acquisition cohort',
        d.acquisitionCohortId?.label ?? 'none',
      ),
      _row('Cohort diagnosis', d.retentionBottleneckSummary),
    ];
  }

  List<Widget> _billingRows(TrialSummaryModel s) {
    return [
      _row('Paywall shown', '${s.paywallShownCount}'),
      _row('Trigger shown', '${s.paywallTriggerShownCount}'),
      _row('Annual plan shown', '${s.annualPlanShownCount}'),
      _row('Monthly plan shown', '${s.monthlyPlanShownCount}'),
      _row('Annual selected', '${s.annualPlanSelectedCount}'),
      _row('Monthly selected', '${s.monthlyPlanSelectedCount}'),
      _row('Continue tapped', '${s.paywallContinueTappedCount}'),
      _row('Dismissed', '${s.paywallDismissedCount}'),
      _row('Restore tapped', '${s.restoreTappedCount}'),
    ];
  }

  List<Widget> _archiveRangeReviewRows(TrialSummaryModel s) {
    return [
      _row('Shown', '${s.archiveRangeReviewShownCount}'),
      _row('Opened', '${s.archiveRangeReviewOpenedCount}'),
      _row('Use check tapped', '${s.archiveRangeReviewUseCheckTappedCount}'),
      _row('Preset changed', '${s.archiveRangeReviewPresetChangedCount}'),
    ];
  }

  List<Widget> _retentionRows(TrialSummaryModel s) {
    return [
      _row('State shown', '${s.retentionStateShownCount}'),
      _row('Due shown', '${s.retentionDueShownCount}'),
      _row('Check set shown', '${s.retentionCheckSetShownCount}'),
      _row('Loop closed shown', '${s.retentionLoopClosedShownCount}'),
      _row('Primary CTA tapped', '${s.retentionPrimaryCtaTappedCount}'),
      _row('Next check ready', '${s.retentionNextCheckReadyCount}'),
      _row('Missed check', '${s.retentionMissedCheckCount}'),
      _row('Reminder scheduled', '${s.reminderScheduledFromRetentionCount}'),
    ];
  }

  List<Widget> _compellingCheckRows(TrialSummaryModel s) {
    return [
      _row('Shown', '${s.compellingCheckShownCount}'),
      _row('Selected', '${s.compellingCheckSelectedCount}'),
      _row('Most specific', '${s.compellingCheckMostSpecificSelectedCount}'),
      _row('Accepted', '${s.compellingCheckAcceptedCount}'),
    ];
  }

  List<Widget> _realReminderRows(TrialSummaryModel s) {
    return [
      _row('Permission requested', '${s.realReminderPermissionRequestedCount}'),
      _row('Permission granted', '${s.realReminderPermissionGrantedCount}'),
      _row('Permission denied', '${s.realReminderPermissionDeniedCount}'),
      _row('Scheduled', '${s.realReminderScheduledCount}'),
      _row('Cancelled', '${s.realReminderCancelledCount}'),
      _row('Unavailable', '${s.realReminderUnavailableCount}'),
    ];
  }

  List<Widget> _currentObjectiveRows(TrialSummaryModel s) {
    return [
      _row('Shown', '${s.currentObjectiveShownCount}'),
      _row('Primary tapped', '${s.currentObjectivePrimaryTappedCount}'),
      _row('Secondary tapped', '${s.currentObjectiveSecondaryTappedCount}'),
      _row('Latest type', s.latestCurrentObjectiveType ?? 'none'),
    ];
  }

  List<Widget> _proValuePreviewRows(TrialSummaryModel s) {
    return [
      _row('Shown', '${s.proValuePreviewShownCount}'),
      _row('Unlock tapped', '${s.proValuePreviewUnlockTappedCount}'),
      _row('Dismissed', '${s.proValuePreviewDismissedCount}'),
      _row('Latest type', s.latestProValuePreviewType ?? 'none'),
    ];
  }

  List<Widget> _objectiveWidgetRows(TrialSummaryModel s) {
    return [
      _row('Refresh attempted', '${s.objectiveWidgetRefreshAttemptedCount}'),
      _row('Refresh succeeded', '${s.objectiveWidgetRefreshSucceededCount}'),
      _row('Refresh failed', '${s.objectiveWidgetRefreshFailedCount}'),
      _row('Cleared', '${s.objectiveWidgetClearedCount}'),
    ];
  }

  List<Widget> _positioningComprehensionRows(TrialSummaryModel s) {
    final rate = s.positioningArchiveMemoryRate;
    final rateLabel = rate == null
        ? 'n/a'
        : '${(rate * 100).toStringAsFixed(0)}%';
    return [
      _row('Asked', '${s.positioningComprehensionAskedCount}'),
      _row('Answered', '${s.positioningComprehensionAnsweredCount}'),
      _row('Understood archive memory',
          '${s.positioningUnderstoodArchiveMemoryCount}'),
      _row('Journal', '${s.positioningJournalCount}'),
      _row('Chat', '${s.positioningChatCount}'),
      _row('Not sure', '${s.positioningNotSureCount}'),
      _row('Rate', rateLabel),
      _row('Pass (≥3/5 archive memory)',
          s.positioningComprehensionPass ? 'yes' : 'no'),
    ];
  }

  List<Widget> _patternMemoryRows(TrialSummaryModel s) {
    return [
      _row('Status', s.activePatternMemoryStatus?.id ?? 'none'),
      _row('Check-ins', '${s.patternMemoryCheckInCount}'),
      _row('Created', '${s.patternMemoryCreatedCount}'),
      _row('Updated', '${s.patternMemoryUpdatedCount}'),
    ];
  }

  List<Widget> _patternProgressRows(TrialSummaryModel s) {
    return [
      _row('Latest type', s.latestPatternProgressType?.id ?? 'none'),
      _row('Moments created', '${s.patternProgressMomentCreatedCount}'),
      _row('Cards shown', '${s.patternProgressCardShownCount}'),
    ];
  }

  List<Widget> _patternNextActionRows(TrialSummaryModel s) {
    return [
      _row('Latest type', s.latestPatternNextActionType?.id ?? 'none'),
      _row('Actions created', '${s.patternNextActionCreatedCount}'),
      _row('Actions used', '${s.patternNextActionUsedCount}'),
    ];
  }

  List<Widget> _habitProofRows(TrialSummaryModel s) {
    return [
      _row('Latest type', s.latestHabitProofType?.id ?? 'none'),
      _row('Proofs created', '${s.habitProofCreatedCount}'),
      _row('Cards shown', '${s.habitProofShownCount}'),
      _row('CTA tapped', '${s.habitProofCtaTappedCount}'),
    ];
  }

  List<Widget> _weeklyPatternRecapRows(TrialSummaryModel s) {
    return [
      _row('Latest type', s.latestWeeklyPatternRecapType?.id ?? 'none'),
      _row('Recaps created', '${s.weeklyPatternRecapCreatedCount}'),
      _row('Cards shown', '${s.weeklyPatternRecapShownCount}'),
      _row('CTA tapped', '${s.weeklyPatternRecapCtaTappedCount}'),
    ];
  }

  List<Widget> _patternShareRows(TrialSummaryModel s) {
    return [
      _row('Cards shown', '${s.patternShareCardShownCount}'),
      _row('Copied', '${s.patternShareCopiedCount}'),
      _row('Opened', '${s.patternShareOpenedCount}'),
      _row('Failed', '${s.patternShareFailedCount}'),
    ];
  }

  List<Widget> _activationLoopRows(TrialSummaryModel s) {
    return [
      _row('First moment', s.activationSavedFirstMoment ? 'yes' : 'no'),
      _row('Tomorrow check', s.activationChoseTomorrowCheck ? 'yes' : 'no'),
      _row('Returned', s.activationReturnedNextDay ? 'yes' : 'no'),
      _row('Loop closed', s.activationClosedLoop ? 'yes' : 'no'),
      _row('Useful / sort-of', s.activationRatedUsefulOrSortOf ? 'yes' : 'no'),
      _row('Next check', s.activationChoseNextCheck ? 'yes' : 'no'),
      _row('Weakest bucket', s.activationWeakestBucket),
      _row('Full loops completed', '${s.activationFullLoopCompletedCount}'),
    ];
  }

  List<Widget> _firstLoopRows(TrialSummaryModel s) {
    return [
      _row('Stage', s.firstLoopStage.id),
      _row('Completed', s.firstLoopCompleted ? 'yes' : 'no'),
      _row('Seconds to first save', '${s.secondsToFirstSave ?? '—'}'),
      _row('Seconds to loop ready', '${s.secondsToLoopReady ?? '—'}'),
      _row('Dropoff point', s.firstLoopDropoffPoint.id),
    ];
  }

  List<Widget> _returnDayRows(TrialSummaryModel s) {
    return [
      _row('Due shown', '${s.returnDayDueShownCount}'),
      _row('Answer selected', '${s.returnDayAnswerSelectedCount}'),
      _row('Loop closed', '${s.returnDayLoopClosedCount}'),
      _row('Latest seconds to answer', '${s.latestSecondsToAnswer ?? '—'}'),
      _row('Latest seconds to loop closed',
          '${s.latestSecondsToLoopClosed ?? '—'}'),
      _row(
        'Completion rate',
        s.returnDayCompletionRate == null
            ? '—'
            : s.returnDayCompletionRate!.toStringAsFixed(2),
      ),
      _row('Dropoff point', s.returnDayDropoffPoint.name),
    ];
  }

  List<Widget> _revenueCatDiagnosticRows() {
    final d = RevenueCatService.instance.diagnostics;
    return [
      _row('revenueCatConfigured', '${d.revenueCatConfigured}'),
      _row('apiKeyMissing', '${d.apiKeyMissing}'),
      _row('offeringsLoaded', '${d.offeringsLoaded}'),
      _row('offeringCount', '${d.offeringCount}'),
      _row('packageCount', '${d.packageCount}'),
      _row('requestedOfferingId', d.requestedOfferingId ?? '—'),
      _row('currentOfferingId', d.currentOfferingId ?? '—'),
      _row(
        'productIdentifiers',
        d.productIdentifiers.isEmpty ? '—' : d.productIdentifiers.join(', '),
      ),
      _row('lastRevenueCatError', d.lastRevenueCatError ?? '—'),
    ];
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
