/** Block synchronous storage/analytics during presentation build (Firefox recursion guard). */

let presentationBuildDepth = 0;

export function isPresentationBuildActive(): boolean {
  return presentationBuildDepth > 0;
}

export function isSideEffectBlocked(): boolean {
  return presentationBuildDepth > 0;
}

export function runPresentationBuild<T>(fn: () => T): T {
  presentationBuildDepth += 1;
  try {
    return fn();
  } finally {
    presentationBuildDepth -= 1;
  }
}
