/**
 * Simplicity Mode v2 — four primary surfaces; everything else via Archive Detail.
 */

export {
  ARCHIVE_IDENTITY_ONE_LINER,
  VOICEMEMORY_ARCHIVE_POSITIONING,
} from "@/lib/product/archive-positioning";

export { ARCHIVE_DETAIL_HUB_ROUTE } from "@/lib/product/archive-relevance";

/** Primary navigation — Record, Archive, Archive Activity, Account only. */
export const SIMPLICITY_PRIMARY_NAV = [
  { href: "/#recorder", label: "Record" },
  { href: "/archive-belief", label: "Archive" },
  { href: "/discover", label: "Archive Activity" },
  { href: "/account", label: "Account" },
] as const;

/** Demoted surfaces — reachable via Archive detail / Account > More. */
export const ARCHIVE_DETAIL_ROUTES = [
  "/archive-detail",
  "/blind-spots",
  "/theories",
  "/updates",
  "/insights",
  "/memory",
  "/journal",
  "/weekly",
  "/monthly",
  "/open-loops",
  "/territories",
  "/threads",
  "/feelings-timeline",
  "/roundups",
  "/bookmarks",
  "/reminders",
  "/patterns",
  "/search",
] as const;

export const ARCHIVE_DETAIL_NAV_LABEL = "Archive detail";

export const ARCHIVE_DETAIL_LINKS = [
  { href: "/archive-detail", label: "Archive detail hub" },
  { href: "/archive-belief#belief-dossier", label: "Belief dossier" },
  { href: "/archive-belief#evidence-locker", label: "Evidence locker" },
  { href: "/memory", label: "Saved moments" },
  { href: "/search", label: "Search" },
  { href: "/blind-spots", label: "Pattern review" },
  { href: "/theories", label: "Archive beliefs" },
  { href: "/updates", label: "Changes feed" },
] as const;

export function isArchiveDetailPath(pathname: string): boolean {
  return ARCHIVE_DETAIL_ROUTES.some(
    (route) => pathname === route || pathname.startsWith(`${route}/`),
  );
}

export function isSimplicityPrimaryPath(pathname: string): boolean {
  if (pathname === "/" || pathname.startsWith("/#")) return true;
  if (pathname === "/record" || pathname.startsWith("/record")) return true;
  if (pathname === "/archive-belief" || pathname.startsWith("/archive-belief")) return true;
  if (pathname === "/discover" || pathname.startsWith("/discover")) return true;
  if (pathname === "/account" || pathname.startsWith("/account")) return true;
  if (pathname.startsWith("/entry/")) return true;
  return false;
}
