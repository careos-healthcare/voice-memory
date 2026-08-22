/**
 * Self-expiring deferrals for invariants whose subject was retired to
 * `apps/web/archived-*`.
 *
 * Production web is marketing, legal, support and beta only — see
 * `packages/shared/lib/site/web-public-production-routes.ts` — and
 * `apps/mobile` is the consumer product. Validators that assert against
 * retired consumer web components cannot pass, and repointing them at the
 * archived copies would validate code that no longer ships.
 *
 * Deferring is only honest if the deferral cannot rot, so every deferral here
 * fails in both directions:
 *
 *   - the live path exists again — the surface came back, the deferral is
 *     stale, and the assertion must be reinstated against it;
 *   - the archived copy is gone too — the content is genuinely gone, so the
 *     validator is asserting nothing and should be deleted outright.
 *
 * A deferral that merely warned would reproduce the vacuous-gate pattern this
 * repo has already been bitten by.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const REPO_ROOT = path.resolve(
  fileURLToPath(new URL(".", import.meta.url)),
  "../..",
);

/** Where a retired `apps/web` path would have been archived to. */
export function archivedCandidatesFor(livePath) {
  const candidates = [];
  if (livePath.startsWith("apps/web/components/")) {
    const rest = livePath.slice("apps/web/components/".length);
    candidates.push(`apps/web/archived-components/_archived/${rest}`);
    candidates.push(`apps/web/archived-components/${rest}`);
  }
  if (livePath.startsWith("apps/web/app/internal/")) {
    const rest = livePath.slice("apps/web/app/internal/".length);
    candidates.push(`apps/web/archived-consumer-routes/internal/${rest}`);
    candidates.push(`apps/web/archived-consumer-routes/_archived/internal/${rest}`);
  }
  if (livePath.startsWith("apps/web/app/")) {
    const rest = livePath.slice("apps/web/app/".length);
    candidates.push(`apps/web/archived-consumer-routes/_archived/${rest}`);
    candidates.push(`apps/web/archived-consumer-routes/${rest}`);
  }
  return candidates;
}

const ARCHIVE_ROOTS = [
  "apps/web/archived-components",
  "apps/web/archived-consumer-routes",
];

/**
 * The archive did not preserve every subpath — `components/internal/*` landed
 * under `archived-components/_archived/debug/*`, for example — so a basename
 * search across the archive roots is the reliable fallback. Directory-index
 * files are matched on their parent segment so `foo/page.tsx` still resolves.
 */
function findArchivedByName(livePath, root) {
  const base = path.basename(livePath);
  const parent = path.basename(path.dirname(livePath));
  const wanted = base === "page.tsx" || base === "route.ts" ? parent : base;

  const search = (dir) => {
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return null;
    }
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === wanted) return full;
        const hit = search(full);
        if (hit) return hit;
      } else if (entry.name === wanted) {
        return full;
      }
    }
    return null;
  };

  for (const archiveRoot of ARCHIVE_ROOTS) {
    const hit = search(path.join(root, archiveRoot));
    if (hit) return path.relative(root, hit);
  }
  return null;
}

/**
 * Returns true while the deferral genuinely holds, meaning the caller should
 * skip the retired assertion. Returns false — after recording a failure via
 * `fail` — if either half of the premise has broken.
 */
export function deferRetiredWebSurface(livePath, fail, root = REPO_ROOT) {
  if (fs.existsSync(path.join(root, livePath))) {
    fail(
      `${livePath} exists again — this check was deferred while the consumer ` +
        `web surface was retired. Remove the deferral and assert against it.`,
    );
    return false;
  }

  const candidates = archivedCandidatesFor(livePath);
  const archived =
    candidates.find((c) => fs.existsSync(path.join(root, c))) ??
    findArchivedByName(livePath, root);

  if (!archived) {
    fail(
      `${livePath} is retired and no archived copy remains (searched ` +
        `${ARCHIVE_ROOTS.join(", ")}) — nothing is being validated. Delete ` +
        `this check instead of leaving it deferred.`,
    );
    return false;
  }

  return true;
}

/**
 * Reads a source file, or returns null when the path is a retired consumer web
 * surface whose deferral still holds. Any other missing file is a real failure.
 */
export function readOrDefer(livePath, fail, root = REPO_ROOT) {
  const full = path.join(root, livePath);
  if (fs.existsSync(full)) return fs.readFileSync(full, "utf8");

  if (livePath.startsWith("apps/web/")) {
    deferRetiredWebSurface(livePath, fail, root);
    return null;
  }

  fail(`${livePath} is missing`);
  return null;
}
