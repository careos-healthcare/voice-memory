#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/homepage/primary-cta.ts",
  "components/homepage/HomepagePrimaryCtaProvider.tsx",
];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Homepage CTA validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const primaryCta = fs.readFileSync(path.join(ROOT, "lib/homepage/primary-cta.ts"), "utf8");
if (!primaryCta.includes("PRIMARY_CTA_PRIORITY")) {
  console.error("Homepage CTA validation failed — priority list missing.");
  process.exit(1);
}

const checks = [
  {
    file: "app/page.tsx",
    tokens: ["HomepagePrimaryCtaProvider", "suppressRecordCta"],
  },
  {
    file: "components/ActivationOnboarding.tsx",
    tokens: ["usePrimaryCtaClaim", 'data-primary-cta="onboarding"', "canShowOnboardingCta"],
  },
  {
    file: "components/Recorder.tsx",
    tokens: ["usePrimaryCtaClaim", 'data-primary-cta="recorder"', "canShowRecorderCta"],
  },
  {
    file: "components/HabitLoopCard.tsx",
    tokens: ["suppressRecordCta"],
  },
];

for (const { file, tokens } of checks) {
  const content = fs.readFileSync(path.join(ROOT, file), "utf8");
  for (const token of tokens) {
    if (!content.includes(token)) {
      console.error(`Homepage CTA validation failed — ${file} missing ${token}`);
      process.exit(1);
    }
  }
}

function assertSingleConstDeclaration(file, name) {
  const content = fs.readFileSync(path.join(ROOT, file), "utf8");
  const matches = content.match(new RegExp(`const ${name}\\s*=`, "g")) ?? [];
  if (matches.length > 1) {
    console.error(
      `Homepage CTA validation failed — duplicate const ${name} in ${file} (${matches.length} declarations).`,
    );
    process.exit(1);
  }
}

for (const [file, names] of [
  ["components/ActivationOnboarding.tsx", ["isLast", "canShowOnboardingCta"]],
  ["components/Recorder.tsx", ["canShowRecorderCta", "canShowRetryCta"]],
]) {
  for (const name of names) {
    assertSingleConstDeclaration(file, name);
  }
}

const pageContent = fs.readFileSync(path.join(ROOT, "app/page.tsx"), "utf8");
const providerOpens = pageContent.match(/<HomepagePrimaryCtaProvider\b/g) ?? [];
const providerCloses = pageContent.match(/<\/HomepagePrimaryCtaProvider>/g) ?? [];
if (providerOpens.length !== 1 || providerCloses.length !== 1) {
  console.error(
    `Homepage CTA validation failed — HomepagePrimaryCtaProvider must wrap the homepage exactly once (found ${providerOpens.length} open, ${providerCloses.length} close).`,
  );
  process.exit(1);
}

const activation = fs.readFileSync(
  path.join(ROOT, "components/ActivationOnboarding.tsx"),
  "utf8",
);
const recorder = fs.readFileSync(path.join(ROOT, "components/Recorder.tsx"), "utf8");
const habit = fs.readFileSync(path.join(ROOT, "components/HabitLoopCard.tsx"), "utf8");
const ctaProvider = fs.readFileSync(
  path.join(ROOT, "components/homepage/HomepagePrimaryCtaProvider.tsx"),
  "utf8",
);

if (ctaProvider.includes("[ctx, id, active]") || ctaProvider.includes("[ctx, id, active,")) {
  console.error(
    "Homepage CTA validation failed — usePrimaryCtaClaim must not depend on ctx in useEffect (update loop risk).",
  );
  process.exit(1);
}

if (
  !ctaProvider.includes("useClientHydrated") ||
  !ctaProvider.includes("if (!register) return active")
) {
  console.error(
    "Homepage CTA validation failed — CTA claim hook must gate on hydration and support missing provider.",
  );
  process.exit(1);
}

if (!activation.includes("Record a reflection") || !activation.includes("canShowOnboardingCta")) {
  console.error(
    "Homepage CTA validation failed — onboarding record CTA must be gated by canShowOnboardingCta.",
  );
  process.exit(1);
}

if (!recorder.includes("Start reflection") || !recorder.includes("canShowRecorderCta")) {
  console.error(
    "Homepage CTA validation failed — recorder start CTA must be gated by canShowRecorderCta.",
  );
  process.exit(1);
}

const habitRecordMatches = habit.match(/Record a reflection/g) ?? [];
if (habitRecordMatches.length > 0) {
  const gated =
    habit.includes("suppressRecordCta") &&
    habit.includes("!suppressRecordCta") || habit.includes("suppressRecordCta ? null");
  if (!gated) {
    console.error(
      "Homepage CTA validation failed — habit loop record CTA must respect suppressRecordCta.",
    );
    process.exit(1);
  }
}

if (pageContent.includes("Start reflection") || pageContent.includes("Record a reflection")) {
  console.error(
    "Homepage CTA validation failed — page must not inline duplicate recorder CTAs.",
  );
  process.exit(1);
}

const dataPrimaryCtaCount =
  (activation.match(/data-primary-cta=/g) ?? []).length +
  (recorder.match(/data-primary-cta=/g) ?? []).length;

if (dataPrimaryCtaCount < 2) {
  console.error(
    "Homepage CTA validation failed — expected data-primary-cta markers on onboarding and recorder.",
  );
  process.exit(1);
}

console.log("Homepage CTA restraint validation passed.");
