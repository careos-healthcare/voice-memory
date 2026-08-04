import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_evidence/archive_evidence.dart';
import '../features/identity_engine/identity_engine.dart';
import '../features/identity_engine/identity_models.dart';
import '../features/identity_engine/identity_profile_store.dart';
import '../features/theme_tracking/theme_tracker_service.dart';
import '../services/app_services.dart';
import '../shared/ui/ai_explainability_card.dart';
import '../theme/app_theme.dart';
import '../widgets/pushed_screen_shell.dart';

/// Evidence-backed identity profile from archive reflections.
class IdentityScreen extends StatelessWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PushedScreenShell(title: 'Identity', body: IdentityView());
  }
}

class IdentityView extends StatefulWidget {
  const IdentityView({super.key});

  @override
  State<IdentityView> createState() => _IdentityViewState();
}

class _IdentityViewState extends State<IdentityView> {
  IdentityProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = AppServices.instance;
      final entries = await s.journal.loadAll();
      final baseline = ThemeTrackerService.parseDiscoverBaseline(
        await s.prefs.discoverBaseline,
      );
      final themeBaseline = ThemeTrackerService.canonicalBaselineFromStored(
        baseline,
      );

      final profile = const IdentityEngine().build(
        entries: entries,
        themeBaseline: themeBaseline,
      );
      try {
        await IdentityProfileStore(s.prefs).save(profile);
      } on Object {
        // Profile persistence is best-effort; rendering must remain available.
      }

      if (!mounted) return;
      setState(() => _profile = profile);
    } on Object {
      if (!mounted) return;
      setState(() => _profile = IdentityProfile.empty());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final profile = _profile;
    if (profile == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: const [
            Text(
              'Record a few moments and ArchiveMe will build your profile.',
              style: TextStyle(color: AppTheme.muted, height: 1.45),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          const Text(
            'YOUR ARCHIVE CURRENTLY BELIEVES',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.9,
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle(profile),
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          ..._buildSections(profile),
        ],
      ),
    );
  }

  String _subtitle(IdentityProfile profile) {
    if (!profile.hasMinimumArchiveEvidence) {
      final need =
          archiveMinEvidenceReflections - profile.evidenceReflectionCount;
      return 'Save $need more moments with enough spoken detail before '
          'the archive can form an evidence-backed identity profile.';
    }
    if (!profile.hasTraits) {
      return 'No identity traits met the evidence threshold yet. '
          'Themes must appear in at least ${IdentityEngine.minTraitEvidenceCount} recordings.';
    }
    return 'Each trait is tied to real recordings — nothing is invented.';
  }

  List<Widget> _buildSections(IdentityProfile profile) {
    if (!profile.hasMinimumArchiveEvidence || !profile.hasTraits) {
      return [
        OutlinedButton(
          onPressed: () => context.go('/record'),
          child: const Text('Save one real moment'),
        ),
      ];
    }

    return [
      if (profile.currentTraits.isNotEmpty) ...[
        _sectionHeader('Current'),
        ...profile.currentTraits.map((t) => _TraitCard(trait: t)),
      ],
      if (profile.emergingTraits.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionHeader('Emerging'),
        ...profile.emergingTraits.map((t) => _TraitCard(trait: t)),
      ],
      if (profile.decliningTraits.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionHeader('Declining'),
        ...profile.decliningTraits.map((t) => _TraitCard(trait: t)),
      ],
    ];
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          color: AppTheme.muted,
        ),
      ),
    );
  }
}

class _TraitCard extends StatelessWidget {
  const _TraitCard({required this.trait});

  final IdentityTrait trait;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trait.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              _metricRow('Confidence', '${trait.confidence}%'),
              _metricRow('Evidence count', '${trait.evidenceCount}'),
              _metricRow('Trend', trait.trendLabel),
              if (trait.supportingQuotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Supporting quotes',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < trait.supportingQuotes.length; i++) ...[
                  _QuoteTile(
                    quote: trait.supportingQuotes[i],
                    entryId: i < trait.supportingRecordingIds.length
                        ? trait.supportingRecordingIds[i]
                        : null,
                  ),
                ],
              ],
              const SizedBox(height: 12),
              AiExplainabilityCard(explainability: trait.explainability),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote, this.entryId});

  final String quote;
  final String? entryId;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '"$quote"',
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 13,
          height: 1.35,
        ),
      ),
    );
    if (entryId == null || entryId!.isEmpty) return child;
    return InkWell(
      onTap: () => context.push('/entry/$entryId'),
      borderRadius: BorderRadius.circular(6),
      child: child,
    );
  }
}
