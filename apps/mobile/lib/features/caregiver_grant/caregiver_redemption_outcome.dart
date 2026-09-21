/// Result of trying to redeem a caregiver invitation (link token or
/// manual reference+code) and activate local caregiver mode.
sealed class CaregiverRedemptionOutcome {
  const CaregiverRedemptionOutcome();
}

class CaregiverRedemptionSucceeded extends CaregiverRedemptionOutcome {
  const CaregiverRedemptionSucceeded();
}

class CaregiverRedemptionFailed extends CaregiverRedemptionOutcome {
  const CaregiverRedemptionFailed(this.message);

  final String message;
}
