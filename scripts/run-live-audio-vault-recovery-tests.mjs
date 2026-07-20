import { runLiveAudioVaultRecoveryRouteTests } from "../lib/reliability/live-audio-vault-recovery-route-tests.ts";

const { failures } = await runLiveAudioVaultRecoveryRouteTests();
if (failures.length > 0) {
  console.error("Live audio vault recovery tests failed:");
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  process.exit(1);
}
console.log("Live audio vault recovery tests passed.");
