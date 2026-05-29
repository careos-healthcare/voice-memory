import seed from "./a11y-dynamic-seed.json" with { type: "json" };

export const A11Y_DYNAMIC_SEED = seed;

export const A11Y_DYNAMIC_ANCHOR_ISO = `${seed.anchorEndDayKey}T12:00:00.000Z`;

export const A11Y_DYNAMIC_ROUTES = {
  entry: `/entry/${seed.primaryEntryId}`,
  entryMissing: "/entry/a11y-missing-entry",
  thread: `/threads/${seed.threadSlug}`,
  threadMissing: "/threads/a11y-missing-thread",
  territory: `/territories/${seed.territorySlug}`,
  territoryMissing: "/territories/a11y-missing-territory",
  roundupWeek: `/roundups/${seed.weekPeriodSlug}`,
  roundupMonth: `/roundups/${seed.monthPeriodSlug}`,
  roundupWeekAlias: "/roundups/week",
};

/** @param {import('@playwright/test').Page} page */
export async function installA11yDynamicSeed(page) {
  await page.addInitScript(
    ({ payload, anchorMs }) => {
      localStorage.setItem(payload.storageKey, JSON.stringify(payload.entries));
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
        storageKey: seed.storageKey,
        storageVersionKey: seed.storageVersionKey,
        storageVersion: seed.storageVersion,
        entries: seed.entries,
      },
      anchorMs: new Date(A11Y_DYNAMIC_ANCHOR_ISO).getTime(),
    },
  );
}
