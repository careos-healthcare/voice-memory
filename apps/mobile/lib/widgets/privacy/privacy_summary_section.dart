import 'dart:async';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The privacy disclosure ArchiveMe owes a reader, as one embeddable block.
///
/// This was the body of `PrivacyScreen`. It moved here because `/privacy` now
/// redirects to `/privacy-trust-centre`, and the disclosure had to arrive at
/// the trust centre before the redirect landed — the processing-providers tile
/// below is the only place in this app that names OpenAI and Google against
/// the specific calls that reach them, and a disclosure that renders on no
/// reachable screen is worse than an absent one.
///
/// A widget rather than copied copy: both surfaces read the same
/// [PrivacyScreenCopy] constants, so a correction lands once.
///
/// Also the review/withdraw surface for [RemoteProcessingConsentStore]: the
/// same decision made once at onboarding (see `RemoteProcessingConsentStep`)
/// can be revisited here at any time.
class PrivacySummarySection extends StatefulWidget {
  const PrivacySummarySection({
    super.key,
    RemoteProcessingConsentStore? consentStore,
  }) : _consentStoreOverride = consentStore;

  final RemoteProcessingConsentStore? _consentStoreOverride;

  @override
  State<PrivacySummarySection> createState() => _PrivacySummarySectionState();
}

class _PrivacySummarySectionState extends State<PrivacySummarySection> {
  RemoteProcessingConsentState? _consent;
  bool _busy = false;

  /// Resolves lazily and defensively: a handful of existing tests pump this
  /// without bringing up `AppServices` at all, and this section must degrade
  /// to "not available" rather than crash the whole screen when that happens.
  RemoteProcessingConsentStore? get _store {
    if (widget._consentStoreOverride != null) {
      return widget._consentStoreOverride;
    }
    if (!AppServices.isInitialized) return null;
    return RemoteProcessingConsentStore(AppServices.instance.prefs);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadConsent());
  }

  Future<void> _loadConsent() async {
    final store = _store;
    if (store == null) return;
    final state = await store.current();
    if (!mounted) return;
    setState(() => _consent = state);
  }

  Future<void> _setConsent(bool allow) async {
    final store = _store;
    if (store == null || _busy) return;
    setState(() => _busy = true);
    try {
      final state = allow ? await store.grant() : await store.withdraw();
      if (!mounted) return;
      setState(() => _consent = state);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFullPolicy(BuildContext context) async {
    final uri = Uri.parse(AppConfig.privacyUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open ${AppConfig.privacyUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WhereWordsGoCallout(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          PrivacyScreenCopy.intro,
          key: const Key('privacy_intro'),
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        // `TrustBadge` used to sit here. Its two lines restate what
        // `PrivacyScreenCopy.sections` says at greater length, so the
        // remote-processing promise and the storage-liveness pointer each
        // appeared twice on one scroll. The sections are the richer form.
        const SizedBox(height: AppSpacing.lg),
        for (final section in PrivacyScreenCopy.sections) ...[
          Text(
            section.title,
            key: Key('privacy_section_${section.title}'),
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            section.body,
            style: ArchiveMobileTypography.explanationBody(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_store != null) ..._remoteProcessingSection(context),
        ExpansionTile(
          key: const Key('privacy_processing_providers'),
          tilePadding: EdgeInsets.zero,
          title: Text(
            PrivacyScreenCopy.processingProvidersTitle,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                PrivacyScreenCopy.processingProvidersBody,
                style: ArchiveMobileTypography.explanationBody(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          key: const Key('privacy_full_policy_link'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            PrivacyScreenCopy.fullPolicyLink,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openFullPolicy(context),
        ),
      ],
    );
  }

  List<Widget> _remoteProcessingSection(BuildContext context) {
    final consented = _consent?.consented ?? false;
    final consentedAt = _consent?.consentedAt;
    return [
      Text(
        PrivacyScreenCopy.remoteProcessingSectionTitle,
        key: const Key('privacy_remote_processing_section'),
        style: ArchiveMobileTypography.cardLabel(context),
      ),
      const SizedBox(height: AppSpacing.xs),
      SwitchListTile(
        key: const Key('privacy_remote_processing_switch'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          PrivacyScreenCopy.remoteProcessingSwitchLabel,
          style: ArchiveMobileTypography.listTitle(context),
        ),
        subtitle: Text(
          consented
              ? PrivacyScreenCopy.remoteProcessingSwitchBodyOn
              : PrivacyScreenCopy.remoteProcessingSwitchBodyOff,
          style: ArchiveMobileTypography.explanationBody(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
        value: consented,
        onChanged: (_consent == null || _busy) ? null : _setConsent,
      ),
      if (consentedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            '${PrivacyScreenCopy.remoteProcessingConsentedAtPrefix}'
            '${_formatDate(consentedAt)}',
            key: const Key('privacy_remote_processing_consented_at'),
            style: ArchiveMobileTypography.explanationBody(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ),
      if (!consented && _consent != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            PrivacyScreenCopy.remoteProcessingWithdrawnFootnote,
            style: ArchiveMobileTypography.explanationBody(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$month/$day/${local.year}';
  }
}

/// First block on the privacy disclosure — visually heavier than the
/// heading/body sections below so a skeptical reader meets the scoped
/// egress claim before the rest of the scroll.
class _WhereWordsGoCallout extends StatelessWidget {
  const _WhereWordsGoCallout();

  static const Key cardKey = Key('privacy_where_words_go');
  static const Key titleKey = Key('privacy_where_words_go_title');
  static const Key bodyKey = Key('privacy_where_words_go_body');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PrivacyScreenCopy.whereWordsGoTitle,
            key: titleKey,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            PrivacyScreenCopy.whereWordsGoBody,
            key: bodyKey,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
        ],
      ),
    );
  }
}
