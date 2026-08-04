# RevenueCat physical-device proof

This is the authoritative manual store-transaction evidence record. Automated
tests and simulators do not satisfy any row below. Never enter `PASS` without a
privacy-safe screenshot/log reference from the physical-device run.

## iOS evidence

| Field | Evidence |
| --- | --- |
| App version/build | NOT RUN |
| Commit SHA | NOT RUN |
| Device model | NOT RUN |
| OS version | NOT RUN |
| Store sandbox/test account type | NOT RUN |
| Test date (ISO 8601) | NOT RUN |
| Tester | NOT RUN |

| Scenario | Result | Entitlement before → after | Privacy-safe evidence reference | Tester | Status |
| --- | --- | --- | --- | --- | --- |
| Monthly purchase | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Yearly purchase | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| User cancellation | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Restore after reinstall | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Restore on second device | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Expiry/refund/revocation | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Offline launch | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |

## Android evidence

| Field | Evidence |
| --- | --- |
| App version/build | NOT RUN |
| Commit SHA | NOT RUN |
| Device model | NOT RUN |
| OS version | NOT RUN |
| Store sandbox/test account type | NOT RUN |
| Test date (ISO 8601) | NOT RUN |
| Tester | NOT RUN |

| Scenario | Result | Entitlement before → after | Privacy-safe evidence reference | Tester | Status |
| --- | --- | --- | --- | --- | --- |
| Monthly purchase | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Yearly purchase | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| User cancellation | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Restore after reinstall | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Restore on second device | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Expiry/refund/revocation | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |
| Offline launch | NOT RUN | NOT RUN | NOT RUN | NOT RUN | BLOCKED |

## Required manual sequence

1. Install the signed store-sandbox build on a physical device.
2. Record free entitlement state and confirm the expected current offering.
3. Purchase monthly; relaunch and confirm `archive_loop_pro`.
4. Use a fresh sandbox account to purchase yearly and confirm the exact yearly
   product identifier.
5. Cancel the store sheet and confirm access remains free.
6. Delete/reinstall, use Restore Purchases without buying again, and confirm
   CustomerInfo restores Pro.
7. Sign in or use a second device where supported, restore, and confirm identity
   linking does not grant access without CustomerInfo.
8. Exercise expiry/refund/revocation using store sandbox controls.
9. Launch offline inside and outside the five-day cache boundary.
10. Store only redacted screenshots/logs; never store receipts, account
    identifiers, API keys, or full CustomerInfo payloads.
