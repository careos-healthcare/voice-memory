function configuredOrigins(): Set<string> {
  const values = [
    process.env.NEXT_PUBLIC_APP_URL,
    process.env.APP_URL,
    ...(process.env.VOICEMEMORY_ALLOWED_API_ORIGINS ?? "").split(","),
  ];
  if (process.env.NODE_ENV !== "production") {
    values.push("http://localhost:3000", "http://127.0.0.1:3000");
  }
  return new Set(
    values
      .map((value) => value?.trim())
      .filter((value): value is string => Boolean(value))
      .map((value) => {
        try {
          return new URL(value).origin;
        } catch {
          return "";
        }
      })
      .filter(Boolean),
  );
}

export function isAllowedVoiceSessionOrigin(request: Request): boolean {
  const origin = request.headers.get("origin")?.trim();
  const referer = request.headers.get("referer")?.trim();
  const candidate = origin || referer;
  if (candidate) {
    try {
      return configuredOrigins().has(new URL(candidate).origin);
    } catch {
      return false;
    }
  }

  // Native clients have no browser Origin. Authentication is still mandatory
  // in the route guard; this marker only distinguishes the documented mobile
  // transport from ambient requests.
  return request.headers.get("x-vm-client") === "voicememory-mobile";
}
