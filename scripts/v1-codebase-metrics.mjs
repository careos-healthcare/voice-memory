import { mkdir, readFile, readdir, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const phase = process.argv.includes("--final") ? "final" : "baseline";
const mobile = path.join(root, "apps/voicememory_mobile");
const dartRoot = path.join(mobile, "lib");
const testRoot = path.join(mobile, "test");

async function filesUnder(directory, predicate = () => true) {
  const output = [];
  async function visit(current) {
    for (const entry of await readdir(current, { withFileTypes: true }).catch(() => [])) {
      if ([".git", "node_modules", ".dart_tool", "build", "Pods", "DerivedData"].includes(entry.name)) {
        continue;
      }
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) await visit(absolute);
      else if (predicate(absolute)) output.push(absolute);
    }
  }
  await visit(directory);
  return output.sort();
}

async function lines(file) {
  return (await readFile(file, "utf8")).split(/\r?\n/).length;
}

async function sizeIfPresent(file) {
  return (await stat(file).catch(() => null))?.size ?? null;
}

function durationFromEnvironment(name) {
  const value = Number.parseFloat(process.env[name] ?? "");
  return Number.isFinite(value) ? value : null;
}

function dependencyNames(pubspec) {
  const names = [];
  let inDependencies = false;
  for (const line of pubspec.split(/\r?\n/)) {
    if (line === "dependencies:") {
      inDependencies = true;
      continue;
    }
    if (inDependencies && /^[^\s]/.test(line) && line.trim()) break;
    const match = inDependencies ? line.match(/^  ([a-zA-Z0-9_]+):/) : null;
    if (match && match[1] !== "flutter") names.push(match[1]);
  }
  return names;
}

const dartFiles = await filesUnder(dartRoot, (file) => file.endsWith(".dart"));
const dartLineRows = await Promise.all(
  dartFiles.map(async (file) => ({ file: path.relative(root, file), lines: await lines(file) })),
);
const routeFiles = await filesUnder(path.join(root, "app/api"), (file) => file.endsWith("/route.ts"));
const packageFiles = await filesUnder(root, (file) => path.basename(file) === "package.json");
const testFiles = await filesUnder(testRoot, (file) => file.endsWith("_test.dart"));
const featureRoot = path.join(dartRoot, "features");
const router = await readFile(path.join(dartRoot, "router/app_router.dart"), "utf8").catch(() => "");
const appServices = path.join(dartRoot, "services/app_services.dart");
const recordingController = path.join(dartRoot, "features/recording/recording_state_controller.dart");
const pubspec = await readFile(path.join(mobile, "pubspec.yaml"), "utf8");
const directDependencies = dependencyNames(pubspec);
const nativePluginNames = directDependencies.filter((name) =>
  /(?:firebase|permission|path_provider|record|audio|share|picker|launcher|device|package_info|purchases|notifications|auth|workmanager|scanner|health|web_auth|nsd|sqlite_vec|drop|battery|blue|ble|webrtc|thermal)/.test(name),
);
const manifest = await readFile(
  path.join(mobile, "android/app/src/main/AndroidManifest.xml"),
  "utf8",
).catch(() => "");
const plist = await readFile(path.join(mobile, "ios/Runner/Info.plist"), "utf8").catch(() => "");
const entitlements = await readFile(
  path.join(mobile, "ios/Runner/Runner-Release.entitlements"),
  "utf8",
).catch(() => "");
const activeAndroidPermissionTags = [
  ...manifest.matchAll(/<uses-permission\b[^>]*>/g),
]
  .map((match) => match[0])
  .filter((tag) => !/tools:node\s*=\s*["']remove["']/.test(tag));
const activeAndroidServiceTags = [...manifest.matchAll(/<service\b[^>]*>/g)]
  .map((match) => match[0])
  .filter((tag) => !/tools:node\s*=\s*["']remove["']/.test(tag));
const activeFeatureDirectories = new Set(
  dartFiles
    .filter((file) => file.startsWith(`${featureRoot}${path.sep}`))
    .map((file) => path.relative(featureRoot, file).split(path.sep)[0]),
);

const metrics = {
  capturedAt: new Date().toISOString(),
  phase,
  productionDartFiles: dartFiles.length,
  productionDartLines: dartLineRows.reduce((sum, row) => sum + row.lines, 0),
  featureDirectories: activeFeatureDirectories.size,
  reachableScreens: (router.match(/\bGoRoute\s*\(/g) ?? []).length,
  productionBackendRoutes: routeFiles.length,
  startupServiceReferences: (await readFile(appServices, "utf8").catch(() => "")).match(/\bService\b/g)?.length ?? 0,
  backgroundServiceReferences:
    dartLineRows.filter((row) => /(?:background|workmanager|notification)/i.test(row.file)).length,
  directFlutterDependencies: directDependencies.length,
  directFlutterDependencyNames: directDependencies,
  nativeFlutterPlugins: nativePluginNames.length,
  nativeFlutterPluginNames: nativePluginNames,
  backendPackageFiles: packageFiles.length,
  iosPermissionKeys: [...new Set(plist.match(/NS[A-Za-z]+UsageDescription/g) ?? [])].sort(),
  iosCapabilities: [...new Set(entitlements.match(/com\.apple\.[A-Za-z0-9.-]+/g) ?? [])].sort(),
  androidPermissions: [
    ...new Set(
      activeAndroidPermissionTags.flatMap(
        (tag) => tag.match(/(?:android\.permission\.[A-Z0-9_]+|com\.android\.vending\.BILLING)/g) ?? [],
      ),
    ),
  ].sort(),
  androidServices: activeAndroidServiceTags.length,
  dartFilesOver500Lines: dartLineRows.filter((row) => row.lines > 500).length,
  dartFilesOver1000Lines: dartLineRows.filter((row) => row.lines > 1000).length,
  dartFilesOver2000Lines: dartLineRows.filter((row) => row.lines > 2000).length,
  largestDartFiles: dartLineRows.sort((a, b) => b.lines - a.lines).slice(0, 25),
  recordingControllerLines: await lines(recordingController),
  appServicesLines: await lines(appServices),
  flutterTestFiles: testFiles.length,
  staticAnalysisDurationSeconds: durationFromEnvironment("V1_STATIC_ANALYSIS_SECONDS"),
  criticalSuiteDurationSeconds: durationFromEnvironment("V1_CRITICAL_SUITE_SECONDS"),
  buildArtifacts: {
    androidDebugApkBytes: await sizeIfPresent(path.join(mobile, "build/app/outputs/flutter-apk/app-debug.apk")),
    androidReleaseApkBytes: await sizeIfPresent(path.join(mobile, "build/app/outputs/flutter-apk/app-release.apk")),
    androidReleaseBundleBytes: await sizeIfPresent(
      path.join(mobile, "build/app/outputs/bundle/release/app-release.aab"),
    ),
    iosAppBytes: await sizeIfPresent(path.join(mobile, "build/ios/iphoneos/Runner.app")),
  },
};

const artifactDirectory = path.join(root, "artifacts/v1-architecture");
await mkdir(artifactDirectory, { recursive: true });
await writeFile(
  path.join(artifactDirectory, `${phase}-metrics.json`),
  `${JSON.stringify(metrics, null, 2)}\n`,
);

const reportPath = path.join(root, "V1_CODEBASE_REDUCTION_REPORT.md");
let report = await readFile(reportPath, "utf8").catch(
  () => "# ArchiveMe V1 codebase reduction report\n\nMetrics are generated by `node scripts/v1-codebase-metrics.mjs`.\n",
);
const marker = `<!-- ${phase.toUpperCase()}_METRICS -->`;
const section = `${marker}
## ${phase === "baseline" ? "Baseline" : "Final"} metrics

\`\`\`json
${JSON.stringify(metrics, null, 2)}
\`\`\`
`;
const markerIndex = report.indexOf(marker);
if (markerIndex >= 0) report = report.slice(0, markerIndex).trimEnd();
await writeFile(reportPath, `${report.trimEnd()}\n\n${section}`, "utf8");
console.log(JSON.stringify(metrics, null, 2));
