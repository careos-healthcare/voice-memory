import permData from "./a11y-dynamic-permutations.json" with { type: "json" };

export const A11Y_PERMUTATIONS = permData.permutations;
export const A11Y_PERM_ANCHOR_ISO = `${permData.anchorEndDayKey}T12:00:00.000Z`;

/** @param {import('@playwright/test').Page} page */
/** @param {{ entries: unknown[] }} permutation */
export async function installA11yPermutation(page, permutation) {
  await page.addInitScript(
    ({ payload, anchorMs, entries }) => {
      localStorage.setItem(payload.storageKey, JSON.stringify(entries));
      localStorage.setItem(payload.storageVersionKey, String(payload.storageVersion));
      const RealDate = Date;
      function PatchedDate(...args) {
        if (args.length === 0) return new RealDate(anchorMs);
        return new RealDate(...args);
      }
      PatchedDate.now = () => anchorMs;
      PatchedDate.parse = RealDate.parse;
      PatchedDate.UTC = RealDate.UTC;
      PatchedDate.prototype = RealDate.prototype;
      window.Date = PatchedDate;
    },
    {
      payload: {
        storageKey: permData.storageKey,
        storageVersionKey: permData.storageVersionKey,
        storageVersion: permData.storageVersion,
      },
      anchorMs: new Date(A11Y_PERM_ANCHOR_ISO).getTime(),
      entries: permutation.entries,
    },
  );
}
