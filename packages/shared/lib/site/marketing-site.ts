/** Canonical marketing domain, URLs, and contact addresses — single source. */

export const MARKETING_DOMAIN = "archiveme.app";

/** Legacy marketing host — redirect to [MARKETING_SITE_URL] when both point at Vercel. */
export const LEGACY_MARKETING_DOMAIN = "voicememory.app";

export const MARKETING_SITE_URL = `https://${MARKETING_DOMAIN}`;

/** Primary customer inbox (web contact, app help, TestFlight feedback). */
export const CONTACT_EMAIL = "hello@archiveme.app";

/** Billing/support alias — route to the same inbox via DNS forwarding. */
export const SUPPORT_EMAIL = "support@archiveme.app";

/** Resend transactional sender for auth codes (domain must be verified in Resend). */
export const AUTH_EMAIL_FROM = `ArchiveMe <noreply@${MARKETING_DOMAIN}>`;

export function marketingPath(path: string): string {
  const normalized = path.startsWith("/") ? path : `/${path}`;
  return `${MARKETING_SITE_URL}${normalized}`;
}

export const MARKETING_PRIVACY_URL = marketingPath("/privacy");
export const MARKETING_CONTACT_URL = marketingPath("/contact");
export const MARKETING_TERMS_URL = marketingPath("/terms");
export const MARKETING_SAFETY_URL = marketingPath("/safety");

/** Env override for sitemap/robots/canonical tags; defaults to production marketing URL. */
export function resolveMarketingSiteUrl(
  env: NodeJS.ProcessEnv = process.env,
): string {
  const override = env.NEXT_PUBLIC_SITE_URL?.trim();
  if (override) {
    return override.replace(/\/$/, "");
  }
  return MARKETING_SITE_URL;
}

export function isLegacyMarketingHost(host: string): boolean {
  const normalized = host.toLowerCase().split(":")[0] ?? host;
  return (
    normalized === LEGACY_MARKETING_DOMAIN ||
    normalized === `www.${LEGACY_MARKETING_DOMAIN}`
  );
}
