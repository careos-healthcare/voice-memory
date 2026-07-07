import '../paywall_alignment/paywall_alignment_copy.dart';

/// Core paid-reason and copy guards for Pro conversion audit v1.
abstract final class ProConversionAuditCopy {
  ProConversionAuditCopy._();

  static const corePaidReason = PaywallAlignmentCopy.corePaidReason;

  static const subscriptionRoute = '/subscription';
  static const proPreviewRoute = '/pro-preview';
  static const proInterestRoute = '/pro-interest';

  static const bannedLiveClaims = <String>[
    'more ai',
    'better chat answers',
    'smarter chat',
    'sync is active',
    'cloud backup included',
    'your archive is backed up',
    'recovered automatically',
    'guaranteed transformation',
    'universal mental health',
  ];

  static const bannedMedicalTerms = <String>[
    'therapy',
    'diagnosis',
    'treatment',
    'medical treatment',
    'mental health assessment',
    'clinical report',
  ];

  static bool mentionsPaidMemoryReason(Iterable<String> strings) {
    final blob = strings.join(' ').toLowerCase();
    return blob.contains('full timeline') ||
        blob.contains('longer story') ||
        blob.contains('longer report') ||
        blob.contains('longer archive') ||
        blob.contains('evidence over time') ||
        blob.contains('pattern history') ||
        blob.contains('preserving the longer archive') ||
        blob.contains('what pro keeps');
  }

  static bool hasNoBannedLiveClaims(Iterable<String> strings) {
    final blob = strings.join(' ').toLowerCase();
    for (final phrase in bannedLiveClaims) {
      if (blob.contains(phrase)) return false;
    }
    return true;
  }

  static bool hasNoMedicalClaims(Iterable<String> strings) {
    for (final line in strings) {
      final lower = line.toLowerCase();
      for (final term in bannedMedicalTerms) {
        if (term == 'therapy' && lower.contains('not therapy')) continue;
        if (term == 'diagnosis' && lower.contains('not a diagnosis')) continue;
        if (term == 'diagnosis' && lower.contains('not advice or a diagnosis')) {
          continue;
        }
        if (lower.contains(term)) return false;
      }
    }
    return true;
  }
}
