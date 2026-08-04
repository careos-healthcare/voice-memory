import { runMonetizedUsageTests } from "../lib/reliability/monetized-usage-tests.ts";

const { failures } = await runMonetizedUsageTests();
if (failures.length) {
  for (const failure of failures) console.error(failure);
  process.exitCode = 1;
} else {
  console.log("Monetized usage tests passed.");
}
