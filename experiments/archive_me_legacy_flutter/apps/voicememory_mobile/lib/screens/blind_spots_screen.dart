import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../features/blind_spots/blind_spot_local.dart';
import '../subscriptions/domain/subscription_models.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/archive_mobile_page_template.dart';
import '../widgets/archive_value_banner.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/value_moment_paywall.dart';

class BlindSpotsScreen extends StatelessWidget {
  const BlindSpotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PushedScreenShell(
      title: 'Archive Insight',
      body: BlindSpotsView(),
    );
  }
}

class BlindSpotsView extends StatefulWidget {
  const BlindSpotsView({super.key});

  @override
  State<BlindSpotsView> createState() => _BlindSpotsViewState();
}

class _BlindSpotsViewState extends State<BlindSpotsView> {
  List<JournalEntry> _entries = [];
  BlindSpotLocalReview? _review;
  SubscriptionState? _entitlements;
  String? _reaction;
  bool _showPaywall = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = AppServices.instance;
    var entries = <JournalEntry>[];
    var ent = SubscriptionState.free();
    BlindSpotLocalReview? review;
    var showPaywall = false;
    String? reaction;

    try {
      await s.paywall.recordBlindSpotsVisit();
      entries = await s.journal.loadEligible();
      ent = await s.subscriptionRepository.refresh();
      review = BlindSpotLocalEngine.buildReview(entries);
      if (review != null) await s.paywall.markFirstBlindSpotSeen();
      showPaywall = await s.paywall.shouldShowPostBlindSpot(
        reflectionCount: entries.length,
        entitlements: ent,
      );
      if (review != null) {
        reaction = (await s.prefs.blindSpotReactions())[review.reviewId];
      }
    } catch (e, st) {
      debugPrint('BlindSpots load: $e');
      if (kDebugMode) debugPrint('$st');
      ent = SubscriptionState.free();
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _review = review;
      _entitlements = ent;
      _showPaywall = showPaywall;
      _reaction = reaction;
    });
  }

  Future<void> _saveReaction(String value) async {
    final review = _review;
    if (review == null) return;
    await AppServices.instance.prefs.saveBlindSpotReaction(
      review.reviewId,
      value,
    );
    setState(() => _reaction = value);
  }

  @override
  Widget build(BuildContext context) {
    final count = _entries.length;
    return SafeArea(
      child: ArchiveMobilePageTemplate(
        eyebrow: 'Archive Insight',
        title: 'Archive Insight',
        lead:
            'This is one reason your archive currently believes what it believes.',
        currentArchiveState: ArchiveValueBanner(entries: _entries),
        actionArea: TextButton(
          onPressed: () => context.go('/archive-belief'),
          child: const Text('Back to Archive'),
        ),
        mainContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (count < AppConfig.patternReviewReflectionTarget) ...[
              const Text(
                'Not enough moments yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '$count of ${AppConfig.patternReviewReflectionTarget} saved moments for a full pattern review. '
                'Recording is never blocked — keep building your archive.',
                style: const TextStyle(color: AppTheme.muted),
              ),
              FilledButton(
                onPressed: () => context.go('/record'),
                child: const Text('Save one real moment'),
              ),
            ] else if (_review == null)
              const Text('Could not build a review from local archive yet.')
            else ...[
              Text(
                _review!.headline,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _section('Observation', _review!.observation),
              _section('Supporting evidence', _review!.possiblePattern),
              _section('Why it may matter', _review!.whyMayMatter),
              _section('One small experiment to try', _review!.experiment),
              const SizedBox(height: 8),
              const Text(
                'Evidence',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final q in _review!.evidenceQuotes)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '“${q.quote}”\n${q.dateLabel}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: _reaction,
                onChanged: (value) {
                  if (value != null) unawaited(_saveReaction(value));
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'How did this land?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    for (final label in [
                      'Obvious',
                      'Interesting',
                      'Surprising',
                      'Uncomfortably accurate',
                      'Completely wrong',
                    ])
                      RadioListTile<String>(value: label, title: Text(label)),
                  ],
                ),
              ),
              ValueMomentPaywallCard(
                surface: PaywallSurface.blindSpot,
                reflectionCount: count,
                entitlements: _entitlements,
                shouldShow: _showPaywall,
                onDismissed: () => setState(() => _showPaywall = false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(color: AppTheme.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
