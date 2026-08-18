import fs from "node:fs";
import path from "node:path";

const FLUTTER_REL = "apps/mobile";

export function flutterRoot(): string {
  return path.join(process.cwd(), FLUTTER_REL);
}

export function flutterPathExists(rel: string): boolean {
  return fs.existsSync(path.join(flutterRoot(), rel));
}

export function readFlutter(rel: string): string {
  const full = path.join(flutterRoot(), rel);
  if (!fs.existsSync(full)) return "";
  return fs.readFileSync(full, "utf8");
}

export function flutterHasRoute(route: string): boolean {
  return readFlutter("lib/router/app_router.dart").includes(route);
}

export function flutterHasScreenToken(token: string, screenRel: string): boolean {
  return readFlutter(screenRel).includes(token);
}
