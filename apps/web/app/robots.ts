import type { MetadataRoute } from "next";

import { resolveMarketingSiteUrl } from "@/lib/site/marketing-site";

const BASE_URL = resolveMarketingSiteUrl();

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: ["/internal/", "/debug/", "/demo/", "/launch/"],
    },
    sitemap: `${BASE_URL}/sitemap.xml`,
  };
}
