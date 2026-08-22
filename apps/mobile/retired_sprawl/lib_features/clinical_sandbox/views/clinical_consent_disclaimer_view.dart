import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/gates/clinical_consent_gate.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/presentation/clinical_consent_copy.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/runtime/clinical_sandbox_runtime.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Mandatory SaMD disclaimer and licensed-provider association form.
class ClinicalConsentDisclaimerView extends StatefulWidget {
  const ClinicalConsentDisclaimerView({
    required this.gate, required this.onCompleted, super.key,
    this.onCancelled,
  });

  final ClinicalConsentGate gate;
  final VoidCallback onCompleted;
  final VoidCallback? onCancelled;

  @override
  State<ClinicalConsentDisclaimerView> createState() =>
      _ClinicalConsentDisclaimerViewState();
}

class _ClinicalConsentDisclaimerViewState
    extends State<ClinicalConsentDisclaimerView> {
  final _formKey = GlobalKey<FormState>();
  final _providerNameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _npiController = TextEditingController();
  final _organizationController = TextEditingController();

  bool _samdAcknowledged = false;
  bool _notForDiagnosisAcknowledged = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _providerNameController.dispose();
    _licenseController.dispose();
    _npiController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_samdAcknowledged || !_notForDiagnosisAcknowledged) {
      setState(() {
        _errorMessage = ClinicalConsentCopy.acknowledgmentsRequired;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final decision = await widget.gate.grant(
      samdLimitationsAcknowledged: _samdAcknowledged,
      notForDiagnosisAcknowledged: _notForDiagnosisAcknowledged,
      providerFullName: _providerNameController.text,
      providerLicenseNumber: _licenseController.text,
      providerNpiOrId: _npiController.text,
      providerOrganization: _organizationController.text,
    );

    if (!mounted) return;

    if (!decision.permitted) {
      setState(() {
        _submitting = false;
        _errorMessage = decision.invalidProviderAssociation
            ? ClinicalConsentCopy.invalidProviderAssociation
            : ClinicalConsentCopy.acknowledgmentsRequired;
      });
      return;
    }

    await ClinicalSandboxRuntime.refreshConsent();
    if (AppServices.isInitialized) {
      AppServices.instance.refreshClinicalSandboxInterceptors();
    }
    if (!mounted) return;
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            ClinicalConsentCopy.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ClinicalConsentCopy.samdLead,
            style: ArchiveMobileTypography.responsiveBody(context),
          ),
          const SizedBox(height: AppSpacing.md),
          _AcknowledgmentTile(
            title: ClinicalConsentCopy.samdLimitationsTitle,
            body: ClinicalConsentCopy.samdLimitationsBody,
            value: _samdAcknowledged,
            onChanged: (next) => setState(() => _samdAcknowledged = next),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AcknowledgmentTile(
            title: ClinicalConsentCopy.notForDiagnosisTitle,
            body: ClinicalConsentCopy.notForDiagnosisBody,
            value: _notForDiagnosisAcknowledged,
            onChanged: (next) =>
                setState(() => _notForDiagnosisAcknowledged = next),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            ClinicalConsentCopy.providerSectionTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ClinicalConsentCopy.providerSectionLead,
            style: ArchiveMobileTypography.responsiveHelper(context),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _providerNameController,
            decoration: const InputDecoration(
              labelText: ClinicalConsentCopy.providerNameLabel,
            ),
            validator: (value) =>
                (value ?? '').trim().length < 3 ? ClinicalConsentCopy.requiredField : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _licenseController,
            decoration: const InputDecoration(
              labelText: ClinicalConsentCopy.licenseLabel,
            ),
            validator: (value) =>
                ClinicalConsentGate.validateProviderAssociation(
                  providerFullName: _providerNameController.text,
                  licenseNumber: value ?? '',
                  npiOrProviderId: _npiController.text,
                  organizationName: _organizationController.text,
                )
                ? null
                : ClinicalConsentCopy.invalidProviderAssociation,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _npiController,
            decoration: const InputDecoration(
              labelText: ClinicalConsentCopy.npiLabel,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _organizationController,
            decoration: const InputDecoration(
              labelText: ClinicalConsentCopy.organizationLabel,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting
                  ? ClinicalConsentCopy.submitting
                  : ClinicalConsentCopy.submitCta,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _submitting ? null : widget.onCancelled,
            child: const Text(ClinicalConsentCopy.cancelCta),
          ),
        ],
      ),
    );
  }
}

class _AcknowledgmentTile extends StatelessWidget {
  const _AcknowledgmentTile({
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: CheckboxListTile(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        title: Text(
          title,
          style: ArchiveMobileTypography.responsiveBody(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          body,
          style: ArchiveMobileTypography.responsiveHelper(context),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}