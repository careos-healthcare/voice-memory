import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_evidence/archive_evidence.dart';
import '../features/identity_engine/identity_engine.dart';
import '../features/identity_engine/identity_models.dart';
import '../features/identity_engine/identity_profile_store.dart';
import '../features/theme_tracking/theme_tracker_service.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/pushed_screen_shell.dart';

/// Evidence-backed identity profile from archive reflections.
class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  IdentityProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = AppServices.instance;
    final entries = await s.journal.loadAll();
    final baselineRaw = await s.prefs.discoverBaseline;
    final baseline = baselineRaw?.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    final themeBaseline = ThemeTrackerService.canonicalBaselineFromStored(
      baseline,
    );

    final profile = const IdentityEngine().build(
      entries: entries,
      themeBaseline: themeBaseline,
    );
    await IdentityProfileStore(s.prefs).save(profile);

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Identity',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
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
                    _subtitle(_profile!),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._buildSections(_profile!),
                ],
              ),
            ),
    );
  }

  String _subtitle(IdentityProfile profile) {
    if (!profile.hasMinimumArchiveEvidence) {
      final need =
          archiveMinEvidenceReflections - profile.evidenceReflectionCount;
      return 'Record $need more reflections with enough spoken detail before '
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
          child: const Text('Record reflection'),
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
