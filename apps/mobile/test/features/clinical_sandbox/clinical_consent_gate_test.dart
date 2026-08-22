import 'package:archiveme_mobile/features/clinical_sandbox/gates/clinical_consent_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClinicalConsentGate.validateProviderAssociation', () {
    test('accepts a well-formed licensed provider association', () {
      expect(
        ClinicalConsentGate.validateProviderAssociation(
          providerFullName: 'Dr. Alex Rivera',
          licenseNumber: 'CA-PSY-12345',
          npiOrProviderId: '1234567890',
          organizationName: 'Rivera Care Group',
        ),
        isTrue,
      );
    });

    test('rejects missing license and short provider name', () {
      expect(
        ClinicalConsentGate.validateProviderAssociation(
          providerFullName: 'Al',
          licenseNumber: 'x',
          npiOrProviderId: '123',
          organizationName: '',
        ),
        isFalse,
      );
    });
  });
}