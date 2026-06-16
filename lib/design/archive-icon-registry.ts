/**
 * Archive Taste v1 — approved lucide icons by semantic role (no mixed libraries).
 */

export const ARCHIVE_ICON_REGISTRY = {
  backup: "Cloud",
  privacy: "Shield",
  sync: "RefreshCw",
  signOut: "LogOut",
  expand: "ChevronDown",
  dismiss: "X",
  menu: "Menu",
} as const;

export type ArchiveIconRole = keyof typeof ARCHIVE_ICON_REGISTRY;

export const ARCHIVE_ICON_PACKAGE = "lucide-react" as const;

/** Only these lucide names may appear on public archive surfaces. */
export const ARCHIVE_APPROVED_LUCIDE_ICONS = new Set(
  Object.values(ARCHIVE_ICON_REGISTRY),
);

export function isApprovedArchiveIcon(name: string): boolean {
  return ARCHIVE_APPROVED_LUCIDE_ICONS.has(name as (typeof ARCHIVE_ICON_REGISTRY)[ArchiveIconRole]);
}
