import type { MetadataRoute } from "next";

import { resolveMarketingSiteUrl } from "@/lib/site/marketing-site";
import { WEB_PUBLIC_PRODUCTION_ROUTES } from "@/lib/site/web-public-production-routes";

const BASE_URL = resolveMarketingSiteUrl();

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date();
  return WEB_PUBLIC_PRODUCTION_ROUTES.map((path) => ({
    url: `${BASE_URL}${path === "/" ? "" : path}`,
    lastModified,
    changeFrequency: path === "/" ? "weekly" : "monthly",
    priority: path === "/" ? 1 : 0.6,
  }));
}
