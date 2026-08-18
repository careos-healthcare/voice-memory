/**
 * Simplicity Mode v2 — web is marketing/legal only; mobile owns product surfaces.
 */

export {
  ARCHIVE_IDENTITY_ONE_LINER,
  VOICEMEMORY_ARCHIVE_POSITIONING,
} from "@/lib/product/archive-positioning";

export { ARCHIVE_DETAIL_HUB_ROUTE } from "@/lib/product/archive-relevance";

/** @deprecated Web no longer hosts consumer navigation — see WEB_MARKETING_NAV. */
export const SIMPLICITY_PRIMARY_NAV = [] as const;

/** @deprecated Retired from public web — mobile app only. */
export const ARCHIVE_DETAIL_ROUTES = [] as const;

export const ARCHIVE_DETAIL_NAV_LABEL = "Archive detail";

/** @deprecated Retired from public web. */
export const ARCHIVE_DETAIL_LINKS = [] as const;

export function isArchiveDetailPath(_pathname: string): boolean {
  return false;
}

export function isSimplicityPrimaryPath(pathname: string): boolean {
  return pathname === "/" || pathname.startsWith("/welcome") || pathname.startsWith("/beta");
}
