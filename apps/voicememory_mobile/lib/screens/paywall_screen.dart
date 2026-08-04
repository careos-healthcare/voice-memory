import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../billing/paywall_route_args.dart';
import '../billing/restore_purchases_flow.dart';
import '../billing/subscription_purchase_coordinator.dart';
import '../features/changes/change_thread_repository.dart';
import '../features/explainable_conclusion/auditable_personal_change_engine.dart';
import '../features/monetization/data/product_value_delivery_recorder.dart';
import '../features/monetization/domain/access_policy_engine.dart';
import '../features/monetization/domain/contextual_paywall_policy.dart';
import '../services/app_services.dart';
import '../subscriptions/domain/subscription_models.dart';
import '../subscriptions/domain/subscription_repository.dart';

/// The single V1 subscription surface.
///
/// Original recordings and entries are never gated here, the offer only
/// appears once free proof has actually been delivered, and the only
/// archive-derived text is a safe count or a thread the user approved.
/// Prices and introductory terms are rendered only from the store-backed
/// repository.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    this.triggerArgs,
    this.subscriptionRepository,
    this.subscriptionService,
    this.attributionStore,
    this.suggestionAttributionStore,
    this.objectionStore,
    this.purchaseIntentStore,
    this.restoreFlow,
    this.billingConfiguredForRestore,
    this.billingReadyOverride,
    this.delayedPaywallProofGateOverride,
    this.entitlementLoader,
    this.contextLoader,
    this.unavailableCapabilities = const {},
  });

  final PaywallRouteArgs? triggerArgs;
  final SubscriptionRepository? subscriptionRepository;

  // Compatibility-only injection points. V1 commercial policy is owned by the
  // canonical subscription repository and AccessPolicyEngine.
  final Object? subscriptionService;
  final Object? attributionStore;
  final Object? suggestionAttributionStore;
  final Object? objectionStore;
  final Object? purchaseIntentStore;
  final Object? restoreFlow;
  final bool Function()? billingConfiguredForRestore;
  final bool Function()? billingReadyOverride;

  /// Overrides whether the first free proof has already been delivered.
  final bool Function()? delayedPaywallProofGateOverride;

  final Future<SubscriptionState> Function()? entitlementLoader;

  /// Supplies the safe contextual count, and an approved thread label when
  /// the user has explicitly named one.
  final Future<ContextualPaywallContext> Function()? contextLoader;

  /// Capabilities that are not available on this build. They are hidden
  /// rather than advertised with a conditional qualifier.
  final Set<CapabilityId> unavailableCapabilities;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final SubscriptionRepository _repository;
  late final SubscriptionPurchaseCoordinator _purchaseCoordinator;
  late final RestorePurchasesFlow _restoreFlow;
  List<SubscriptionOffer> _offers = const [];
  EntitlementSnapshot _entitlement = const EntitlementSnapshot.free();
  ContextualPaywallContext _context = const ContextualPaywallContext();
  ProductValueState _productValue = const ProductValueState();
  String? _selectedOfferId;
  String? _error;
  bool _loading = true;
  bool _purchasing = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.subscriptionRepository ??
        AppServices.instance.subscriptionRepository;
    _purchaseCoordinator = SubscriptionPurchaseCoordinator(
      repository: _repository,
    );
    _restoreFlow = switch (widget.restoreFlow) {
      final RestorePurchasesFlow flow => flow,
      _ => RestorePurchasesFlow(
        repository: _repository,
        coordinator: _purchaseCoordinator,
      ),
    };
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final cached = widget.entitlementLoader == null
          ? await _repository.loadCachedState()
          : await widget.entitlementLoader!();
      final offers = await _repository.loadOffers();
      final retained = offers
          .where(
            (offer) =>
                offer.period == SubscriptionPeriod.monthly ||
                offer.period == SubscriptionPeriod.annual,
          )
          .toList(growable: false);
      final productValue = await _loadProductValue();
      final context = await _loadContext();
      if (!mounted) return;
      setState(() {
        _entitlement = switch (cached ?? _repository.currentState) {
          final SubscriptionState state =>
            EntitlementSnapshot.fromSubscriptionState(state),
          _ => const EntitlementSnapshot.free(),
        };
        _productValue = productValue;
        _context = context;
        _offers = retained;
        _selectedOfferId = _preferredOffer(retained)?.id;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Store pricing is unavailable right now.';
      });
    }
  }

  Future<ProductValueState> _loadProductValue() async {
    if (widget.delayedPaywallProofGateOverride != null) {
      return const ProductValueState();
    }
    try {
      final ledger = await ProductValueDeliveryRecorder.ensureLoaded();
      return ledger.productValue;
    } on Object {
      return const ProductValueState();
    }
  }

  Future<ContextualPaywallContext> _loadContext() async {
    if (widget.contextLoader != null) return widget.contextLoader!();
    if (!AppServices.isInitialized) return const ContextualPaywallContext();
    try {
      final entries = await AppServices.instance.journalStore.loadEligible();
      if (entries.length < 2) return const ContextualPaywallContext();
      final ordered = [...entries]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final anchor = ordered.first;
      final comparable =
          1 +
          ordered
              .skip(1)
              .where(
                (entry) =>
                    AuditablePersonalChangeEngine.areRelated(entry, anchor),
              )
              .length;
      final label = await _userNamedThreadLabel();
      if (label == null) {
        return ContextualPaywallContext(comparableMomentCount: comparable);
      }
      return ContextualPaywallContext.withApprovedThread(
        label: label,
        approvedByUser: true,
        comparableMomentCount: comparable,
      );
    } on Object {
      return const ContextualPaywallContext();
    }
  }

  /// A thread label may only be shown once the user named the thread
  /// themselves. An inferred label stays inside the app and never reaches a
  /// commercial surface.
  Future<String?> _userNamedThreadLabel() async {
    try {
      final projection = await ChangeThreadRepository.refresh();
      for (final view in projection.threads) {
        if (!view.thread.labelIsUserConfirmed) continue;
        if (!view.thread.isVisible) continue;
        final label = view.thread.userEditableLabel.trim();
        if (label.isNotEmpty) return label;
      }
    } on Object {
      // A paywall must never fail because thread history could not be read.
    }
    return null;
  }

  bool get _freeProofDelivered =>
      widget.delayedPaywallProofGateOverride?.call() ??
      ContextualPaywallPolicy.freeProofDelivered(_productValue);

  static SubscriptionOffer? _preferredOffer(List<SubscriptionOffer> offers) {
    for (final offer in offers) {
      if (offer.period == SubscriptionPeriod.annual) return offer;
    }
    return offers.firstOrNull;
  }

  Future<void> _purchase() async {
    final offerId = _selectedOfferId;
    if (offerId == null || _purchasing) return;
    final offer = _offers
        .where((candidate) => candidate.id == offerId)
        .firstOrNull;
    if (offer == null) {
      setState(
        () => _error = 'That store plan expired. Reload pricing and try again.',
      );
      return;
    }
    setState(() {
      _purchasing = true;
      _error = null;
    });
    try {
      final state = await _purchaseCoordinator.purchase(offer);
      if (!mounted) return;
      final entitlement = EntitlementSnapshot.fromSubscriptionState(state);
      setState(() => _entitlement = entitlement);
      if (entitlement.hasProAccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ArchiveMe Pro is active.')),
        );
      }
    } on SubscriptionPurchaseException catch (error) {
      if (mounted) {
        setState(() => _error = _purchaseErrorMessage(error));
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Purchase could not be completed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    if (_restoring || _restoreFlow.isBusy) return;
    setState(() {
      _restoring = true;
      _error = null;
    });
    try {
      final result = await _restoreFlow.restore();
      if (!mounted) return;
      final state = result.subscriptionState;
      if (state != null) {
        setState(
          () => _entitlement = EntitlementSnapshot.fromSubscriptionState(state),
        );
      }
      if (result.outcome == RestorePurchasesOutcome.error ||
          result.outcome == RestorePurchasesOutcome.unavailable) {
        setState(() => _error = result.userMessage);
        return;
      }
      if (result.outcome == RestorePurchasesOutcome.skippedBusy) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.userMessage)));
    } on Object {
      if (mounted) {
        setState(() => _error = 'Purchases could not be restored right now.');
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  static String? _purchaseErrorMessage(SubscriptionPurchaseException error) {
    return switch (error.kind) {
      SubscriptionPurchaseFailureKind.cancelled => null,
      SubscriptionPurchaseFailureKind.temporary =>
        'The store is temporarily unreachable. Check your connection and try again.',
      SubscriptionPurchaseFailureKind.pending =>
        'This purchase is pending. Pro activates after the store confirms it.',
      SubscriptionPurchaseFailureKind.productUnavailable =>
        'That plan is unavailable. Reload store pricing and choose another plan.',
      SubscriptionPurchaseFailureKind.verification =>
        'The purchase could not be verified. Try Restore purchases.',
      SubscriptionPurchaseFailureKind.unexpected =>
        'Purchase could not be completed. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPro = _entitlement.hasProAccess;
    final content = ContextualPaywallPolicy.resolve(
      entitlement: _entitlement,
      productValue: _productValue,
      context: _context,
      unavailableCapabilities: widget.unavailableCapabilities,
      freeProofDeliveredOverride: _freeProofDelivered,
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close subscription',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/account'),
          icon: const Icon(Icons.close),
        ),
        title: const Text('ArchiveMe Pro'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (hasPro)
              const _StatusCard(
                icon: Icons.verified,
                message: 'ArchiveMe Pro is active.',
              )
            else if (!content.visible)
              _StatusCard(
                key: const Key('paywall_awaiting_free_proof'),
                icon: Icons.hourglass_empty,
                message: ContextualPaywallCopy.awaitingFreeProof,
              )
            else ...[
              if (content.contextLine case final contextLine?) ...[
                Text(
                  contextLine,
                  key: const Key('paywall_context_line'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
              ],
              Semantics(
                header: true,
                child: Text(
                  content.primaryCopy,
                  key: const Key('paywall_primary_copy'),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ContextualPaywallCopy.positioning,
                key: const Key('paywall_positioning_line'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                content.supportingCopy,
                key: const Key('paywall_supporting_copy'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              for (final line in content.capabilityLines)
                _Outcome(icon: Icons.check, text: line),
              const SizedBox(height: 24),
              if (_offers.isEmpty)
                const _StatusCard(
                  icon: Icons.info_outline,
                  message:
                      'Store pricing is unavailable. No purchase can be '
                      'started until verified prices load.',
                )
              else
                ..._offers.map(_offerCard),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: const Key('paywall_error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (!_loading && !hasPro && content.visible)
              FilledButton(
                key: const Key('paywall_purchase_button'),
                onPressed: _selectedOfferId == null || _purchasing
                    ? null
                    : _purchase,
                child: Text(_purchasing ? 'Connecting to store…' : 'Continue'),
              ),
            TextButton(
              key: const Key('paywall_restore_button'),
              onPressed: _restoring ? null : _restore,
              child: Text(
                _restoring ? 'Restoring purchases…' : 'Restore purchases',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ContextualPaywallCopy.originalsNeverGated,
              key: const Key('paywall_originals_note'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Purchases and restores use your Apple or Google store account. '
              'Signing in also syncs verified Pro access across your devices.',
              key: const Key('paywall_billing_identity_note'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.push('/terms'),
                  child: const Text('Terms'),
                ),
                TextButton(
                  onPressed: () => context.push('/privacy'),
                  child: const Text('Privacy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _offerCard(SubscriptionOffer offer) {
    final selected = offer.id == _selectedOfferId;
    final period = switch (offer.period) {
      SubscriptionPeriod.monthly => 'Monthly',
      SubscriptionPeriod.annual => 'Annual',
      _ => '',
    };
    return Semantics(
      selected: selected,
      button: true,
      label: '$period plan, ${offer.price}',
      child: Card(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        child: RadioGroup<String>(
          groupValue: _selectedOfferId,
          onChanged: (value) => setState(() => _selectedOfferId = value),
          child: RadioListTile<String>(
            value: offer.id,
            title: Text(period),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.price),
                if (offer.introductoryDisplay case final intro?) Text(intro),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, semanticLabel: null),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, semanticLabel: null),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
