import 'package:archiveme_mobile/features/caregiver_grant/caregiver_redemption_outcome.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_redemption_service.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _EntryPhase { idle, redeeming, failed }

/// Where a caregiver lands after opening an invitation link, or after
/// typing a manual reference+code when the link doesn't fire.
///
/// [linkToken] arrives via the Universal Link (see
/// caregiver_invitation_link_listener.dart) as a query parameter,
/// preserved through cold starts. When present, redemption is attempted
/// automatically on first frame. When absent, shows a manual entry form.
class CaregiverConsentEntryScreen extends StatefulWidget {
  const CaregiverConsentEntryScreen({this.linkToken, super.key});

  final String? linkToken;

  @override
  State<CaregiverConsentEntryScreen> createState() =>
      _CaregiverConsentEntryScreenState();
}

class _CaregiverConsentEntryScreenState
    extends State<CaregiverConsentEntryScreen> {
  final _referenceController = TextEditingController();
  final _codeController = TextEditingController();
  final _service = CaregiverRedemptionService();

  _EntryPhase _phase = _EntryPhase.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final token = widget.linkToken;
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redeemWithLinkToken(token);
      });
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeemWithLinkToken(String token) async {
    setState(() {
      _phase = _EntryPhase.redeeming;
      _errorMessage = null;
    });
    final outcome = await _service.redeemWithLinkToken(token);
    _handleOutcome(outcome);
  }

  Future<void> _redeemWithManualCode() async {
    final reference = _referenceController.text.trim();
    final code = _codeController.text.trim();
    if (reference.isEmpty || code.isEmpty) {
      setState(() {
        _errorMessage = 'Enter both the reference and the code.';
      });
      return;
    }
    setState(() {
      _phase = _EntryPhase.redeeming;
      _errorMessage = null;
    });
    final outcome = await _service.redeemWithManualCode(
      reference: reference,
      code: code,
    );
    _handleOutcome(outcome);
  }

  void _handleOutcome(CaregiverRedemptionOutcome outcome) {
    if (!mounted) return;
    switch (outcome) {
      case CaregiverRedemptionSucceeded():
        context.go(RouteCatalog.caregiverHome);
      case CaregiverRedemptionFailed(:final message):
        setState(() {
          _phase = _EntryPhase.failed;
          _errorMessage = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caregiver Access')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Icon(
                Icons.favorite_outline,
                size: 48,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                "You've been invited",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Someone has shared limited access to their archive with "
                'you. Confirm below to see what they chose to share.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_phase == _EntryPhase.redeeming)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (widget.linkToken == null || _phase == _EntryPhase.failed)
                  _buildManualEntryForm(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualEntryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "If you have a reference and code instead of a link, "
          'enter them below.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _referenceController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Reference',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Code',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _redeemWithManualCode,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
