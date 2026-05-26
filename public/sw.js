/* VoiceMemory offline shell — warm capture route, cache recorder shell only. */
const CACHE = "voicememory-shell-v2";
const SHELL = ["/", "/record", "/offline"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("message", (event) => {
  if (event.data?.type !== "warm-capture") return;
  const path = event.data.path ?? "/record";
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      fetch(path)
        .then((response) => {
          if (response.ok) return cache.put(path, response);
        })
        .catch(() => undefined),
    ),
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  const isCaptureNav =
    event.request.mode === "navigate" &&
    (url.pathname === "/record" || url.searchParams.get("record") === "1");

  event.respondWith(
    (isCaptureNav
      ? caches.match("/record").then((cached) => cached ?? fetch(event.request))
      : fetch(event.request)
    )
      .then((response) => {
        if (response.ok && SHELL.includes(url.pathname)) {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(event.request, copy));
        }
        return response;
      })
      .catch(async () => {
        const cached =
          (await caches.match(event.request)) ?? (await caches.match("/record"));
        if (cached) return cached;
        if (event.request.mode === "navigate") {
          const offline = await caches.match("/offline");
          if (offline) return offline;
        }
        return new Response("Offline", { status: 503, statusText: "Offline" });
      }),
  );
});
