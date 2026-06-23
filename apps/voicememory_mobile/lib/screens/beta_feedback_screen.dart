import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta_feedback/beta_feedback_copy.dart';
import '../features/beta_feedback/beta_feedback_engine.dart';
import '../features/beta_feedback/beta_feedback_models.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/share/archive_share_actions.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Local beta proof summary and feedback editor — no uploads, no entry text.
class BetaFeedbackScreen extends StatefulWidget {
  const BetaFeedbackScreen({
    super.key,
    this.journalService,
    this.watchlistStore,
    this.feedbackStore,
    this.engine = const BetaFeedbackEngine(),
  });

  final JournalService? journalService;
  final ArchiveWatchlistStore? watchlistStore;
  final BetaFeedbackStore? feedbackStore;
  final BetaFeedbackEngine engine;

  @override
  State<BetaFeedbackScreen> createState() => _BetaFeedbackScreenState();
}

class _BetaFeedbackScreenState extends State<BetaFeedbackScreen> {
  List<JournalEntry> _entries = const [];
  BetaFeedbackState _feedback = BetaFeedbackState.empty;
  BetaFeedbackUsefulness? _usefulness;
  BetaFeedbackClarity? _clarity;
  final _noteController = TextEditingController();
  int _watchThemesCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final journal = widget.journalService ?? AppServices.instance.journal;
    final watchlist = widget.watchlistStore ??
        ArchiveWatchlistStore(AppServices.instance.prefs);
    await BetaFeedbackStore.ensureLoaded();
    final entries = await journal.loadAll();
    final watchItems = await watchlist.loadItems();
    if (!mounted) return;
    final feedback = BetaFeedbackStore.cached;
    setState(() {
      _entries = entries;
      _feedback = feedback;
      _usefulness = feedback.usefulness;
      _clarity = feedback.clarity;
      if (feedback.note case final note?) {
        _noteController.text = note;
      }
      _watchThemesCount = watchItems.length;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveFeedback() async {
    final store = widget.feedbackStore ?? BetaFeedbackStore.instance();
    await store.saveResponse(
      usefulness: _usefulness,
      clarity: _clarity,
      note: _noteController.text,
    );
    if (!mounted) return;
    setState(() => _feedback = BetaFeedbackStore.cached);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(BetaFeedbackCopy.thanksMessage)),
    );
  }

  Future<void> _copySummary(BetaFeedbackSummary summary) async {
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: BetaFeedbackCopy.buildSummaryText(summary),
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      ArchiveShareActions.showFeedback(
        context,
        BetaFeedbackCopy.summaryCopied,
      );
    }
  }

  Future<void> _copyTestimonial(BetaFeedbackState state) async {
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: BetaFeedbackCopy.testimonialFor(state),
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      await (widget.feedbackStore ?? BetaFeedbackStore.instance())
          .markTestimonialCopied();
      if (!context.mounted) return;
      setState(() => _feedback = BetaFeedbackStore.cached);
      ArchiveShareActions.showFeedback(
        context,
        BetaFeedbackCopy.testimonialCopied,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PushedScreenShell(
        title: BetaFeedbackCopy.screenTitle,
        fallbackRoute: '/support-feedback',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = widget.engine.buildSummary(
      entries: _entries,
      watchThemesCount: _watchThemesCount,
      feedbackState: _feedback,
    );

    return PushedScreenShell(
      title: BetaFeedbackCopy.screenTitle,
      fallbackRoute: '/support-feedback',
      body: SingleChildScrollView(
        key: const Key('beta_feedback_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              BetaFeedbackCopy.screenIntro,
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _sectionTitle(context, BetaFeedbackCopy.summarySectionTitle),
            _summaryRow(
              context,
              label: BetaFeedbackCopy.summaryMomentsSaved,
              value: '${summary.momentsSavedCount}',
            ),
            _summaryRow(
              context,
              label: BetaFeedbackCopy.summaryDepthLevel,
              value: summary.depthLevelLabel,
            ),
            _summaryRow(
              context,
              label: BetaFeedbackCopy.summaryWatchThemes,
              value: '${summary.watchThemesCount}',
            ),
            _summaryRow(
              context,
              label: BetaFeedbackCopy.summaryUsefulness,
              value: summary.usefulnessLabel,
            ),
            _summaryRow(
              context,
              label: BetaFeedbackCopy.summaryClarity,
              value: summary.clarityLabel,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              BetaFeedbackCopy.summaryNoPrivateEntries,
              key: const Key('beta_feedback_no_private_entries'),
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            _sectionTitle(context, BetaFeedbackCopy.editSectionTitle),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _chip(
                  key: const Key('beta_feedback_screen_useful'),
                  label: BetaFeedbackCopy.usefulnessUseful,
                  selected: _usefulness == BetaFeedbackUsefulness.useful,
                  onTap: () => setState(
                    () => _usefulness = BetaFeedbackUsefulness.useful,
                  ),
                ),
                _chip(
                  key: const Key('beta_feedback_screen_not_yet'),
                  label: BetaFeedbackCopy.usefulnessNotYet,
                  selected: _usefulness == BetaFeedbackUsefulness.notYet,
                  onTap: () => setState(
                    () => _usefulness = BetaFeedbackUsefulness.notYet,
                  ),
                ),
                _chip(
                  key: const Key('beta_feedback_screen_understood'),
                  label: BetaFeedbackCopy.clarityUnderstood,
                  selected: _clarity == BetaFeedbackClarity.understood,
                  onTap: () => setState(
                    () => _clarity = BetaFeedbackClarity.understood,
                  ),
                ),
                _chip(
                  key: const Key('beta_feedback_screen_confused'),
                  label: BetaFeedbackCopy.clarityConfused,
                  selected: _clarity == BetaFeedbackClarity.confused,
                  onTap: () => setState(
                    () => _clarity = BetaFeedbackClarity.confused,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('beta_feedback_screen_note'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: BetaFeedbackCopy.noteLabel,
                hintText: BetaFeedbackCopy.noteHint,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: BetaFeedbackStore.maxNoteLength,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('beta_feedback_screen_save'),
                onPressed: (_usefulness != null || _clarity != null)
                    ? _saveFeedback
                    : null,
                child: const Text(BetaFeedbackCopy.saveButton),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_feedback_copy_summary'),
                onPressed: () => _copySummary(summary),
                child: const Text(BetaFeedbackCopy.copySummaryButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_feedback_copy_testimonial'),
                onPressed: () => _copyTestimonial(_feedback),
                child: const Text(BetaFeedbackCopy.copyTestimonialButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: ArchiveMobileTypography.cardLabel(context),
      ),
    );
  }

  static Widget _summaryRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      key: key,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
