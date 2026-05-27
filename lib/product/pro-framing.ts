/** Pro positioning — memory return and continuity, not export/productivity. */

export const PRO_HEADLINE = "Deeper resurfacing across your full archive";

export const PRO_DESCRIPTION =
  "Pro connects long-term continuity: full-archive return threads, weekly remembered moments, and a printable private record. Export stays available when you need a copy.";

export const PRO_FEATURE_BULLETS = [
  "Full-archive resurfacing — phrases and threads across your whole history",
  "Weekly remembered moments from your own words",
  "Long-term return threads and open loops across years of speech",
  "Printable private archive for quiet reading away from the app",
  "Encrypted backup when you sign in (optional sync)",
  "Export JSON or text when you want a portable copy",
] as const;

export const PRO_GATE_UNLIMITED_ARCHIVE = {
  title: "Full archive continuity is part of Pro",
  detail:
    "Free keeps recent reflections active. Pro lets your whole history resurface in memory, search, and return threads.",
  feature: "unlimited_archive",
} as const;

export const PRO_GATE_DEEPER_RESURFACING = {
  title: "Full-history resurfacing is part of Pro",
  detail:
    "Pro draws return threads and callbacks from your entire archive — not only the last week of speech.",
  feature: "deeper_resurfacing",
} as const;

export const PRO_GATE_EXPORT = {
  title: "Printable archive and exports are part of Pro",
  detail:
    "Pro includes weekly remembered moments and a printable private archive. JSON export is there when you need a copy.",
  feature: "export_reports",
} as const;
