import { containsOverconfidentResurfacingCopy } from "@/lib/resurfacing/resurfacing-ambiguity";

const BANNED_IN_CAUTIOUS = [
  "you are",
  "you always",
  "this means",
  "clearly",
  "definitely",
  "you still",
  "you need",
] as const;

export function isOverconfidentResurfacingCopy(text: string): boolean {
  return containsOverconfidentResurfacingCopy(text);
}

export function passesOverconfidentCopyGate(
  text: string,
  cautious: boolean,
): boolean {
  if (!cautious) return true;
  return !isOverconfidentResurfacingCopy(text);
}

export { BANNED_IN_CAUTIOUS };
