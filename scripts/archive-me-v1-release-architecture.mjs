import { access, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

export const CLASSIFICATIONS = [
  "RETAIN",
  "CONSOLIDATE",
  "REMOVE",
  "BACKEND_ONLY",
  "MIGRATION_ONLY",
  "LEGACY_COMPATIBILITY",
  "EXPERIMENTAL_ISOLATED",
];

const SCRIPT_PATH = fileURLToPath(import.meta.url);
const DEFAULT_ROOT = path.resolve(path.dirname(SCRIPT_PATH), "..");
const CONTRACT_PATH = "config/product/archive_me_v1_release_contract.json";
const REPORT_PATH = "artifacts/v1-architecture/v1-reachability-report.json";
const MARKDOWN_PATH = "V1_REACHABILITY_REPORT.md";
const REMOVAL_PATH = "V1_REMOVAL_MANIFEST.md";

async function exists(file) {
  return access(file).then(() => true, () => false);
}

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

function unique(values) {
  return [...new Set(values)].sort();
}

function sameMembers(left, right) {
  return JSON.stringify(unique(left)) === JSON.stringify(unique(right));
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

function routeCatalogValues(source) {
  return Object.fromEntries(
    [...source.matchAll(/static const\s+(\w+)\s*=\s*'([^']+)'/g)].map((match) => [match[1], match[2]]),
  );
}

function constCollection(source, name, catalog) {
  const match = source.match(new RegExp(`static const ${name}\\s*=\\s*(?:<[^>]+>)?[\\[{]([\\s\\S]*?)[\\]}];`));
  if (!match) return [];
  const values = [...match[1].matchAll(/'([^']+)'/g)].map((item) => item[1]);
  for (const reference of match[1].matchAll(/RouteCatalog\.(\w+)/g)) {
    if (catalog[reference[1]]) values.push(catalog[reference[1]]);
  }
  for (const reference of match[1].matchAll(/^\s*(\w+),?\s*$/gm)) {
    if (catalog[reference[1]]) values.push(catalog[reference[1]]);
  }
  return unique(values);
}

function resolveDartImport(sourceFile, specifier, mobileLib) {
  if (specifier.startsWith("dart:") || specifier.startsWith("package:flutter")) return null;
  let candidate;
  if (specifier.startsWith("package:voicememory_mobile/")) {
    candidate = path.join(mobileLib, specifier.slice("package:voicememory_mobile/".length));
  } else if (!specifier.startsWith("package:")) {
    candidate = path.resolve(path.dirname(sourceFile), specifier);
  } else {
    return null;
  }
  return candidate.endsWith(".dart") ? candidate : `${candidate}.dart`;
}

async function importGraph(root, entryPoints) {
  const mobileLib = path.join(root, "apps/voicememory_mobile/lib");
  const pending = entryPoints.map((entry) => path.join(root, entry));
  const visited = new Set();
  const edges = [];
  const unresolvedLocalImports = [];
  const packageImports = [];
  const sourceByFile = new Map();
  while (pending.length) {
    const current = pending.pop();
    if (visited.has(current) || !(await exists(current))) continue;
    visited.add(current);
    const source = await readFile(current, "utf8");
    sourceByFile.set(current, source);
    const imports = [...source.matchAll(/^\s*(?:import|export|part)\s+['"]([^'"]+)['"]/gm)]
      .map((match) => match[1]);
    for (const specifier of imports) {
      if (specifier.startsWith("package:") && !specifier.startsWith("package:voicememory_mobile/")) {
        packageImports.push(specifier.slice("package:".length).split("/")[0]);
      }
      const resolved = resolveDartImport(current, specifier, mobileLib);
      if (!resolved) continue;
      if (!(await exists(resolved))) {
        unresolvedLocalImports.push({
          from: path.relative(root, current),
          import: specifier,
          expected: path.relative(root, resolved),
        });
        continue;
      }
      edges.push({
        from: path.relative(root, current),
        to: path.relative(root, resolved),
      });
      if (!visited.has(resolved)) pending.push(resolved);
    }
  }
  return {
    reachableFiles: [...visited].map((file) => path.relative(root, file)).sort(),
    edges: edges.sort((a, b) => `${a.from}:${a.to}`.localeCompare(`${b.from}:${b.to}`)),
    packageImports: unique(packageImports),
    unresolvedLocalImports: unresolvedLocalImports.sort((a, b) =>
      `${a.from}:${a.import}`.localeCompare(`${b.from}:${b.import}`),
    ),
    sourceByFile,
  };
}

function relativePath(root, file) {
  return path.relative(root, file).replaceAll(path.sep, "/");
}

function filesWithin(files, module) {
  return files.filter((file) => file === module || file.startsWith(`${module}/`));
}

function routeFileToApi(root, file) {
  const relative = path.relative(path.join(root, "app/api"), file).replaceAll(path.sep, "/");
  return `/api/${relative.replace(/\/route\.ts$/, "").replace(/\[([^\]]+)\]/g, ":$1")}`;
}

function positiveAndroidPermissions(source) {
  return unique(
    [...source.matchAll(/<uses-permission(?:-sdk-23)?\s+android:name="([^"]+)"([^>]*)\/>/g)]
      .filter((match) => !match[2].includes('tools:node="remove"'))
      .map((match) => match[1]),
  );
}

function plistKeys(source) {
  return unique([...source.matchAll(/<key>([^<]+)<\/key>/g)].map((match) => match[1]));
}

function classifyTests(files) {
  return files.map((file) => ({
    file,
    classification:
      /v1_|primary_navigation_shell/.test(file) ? "ARCHITECTURE_GUARD" :
      /record|journal|archive|belief|subscription|auth|sync/.test(file) ? "RETAINED_BEHAVIOR" :
      "NON_V1",
  }));
}

function markdownList(values) {
  return values.length ? values.map((value) => `- \`${value}\``).join("\n") : "- None";
}

export async function buildArchitectureReport(root = DEFAULT_ROOT) {
  const contract = JSON.parse(await readFile(path.join(root, CONTRACT_PATH), "utf8"));
  const productSource = await readFile(path.join(root, contract.product.productContract), "utf8");
  const catalogSource = await readFile(path.join(root, contract.product.routeCatalog), "utf8");
  const routerSource = await readFile(path.join(root, contract.product.router), "utf8");
  const startupSource = await readFile(
    path.join(root, "apps/voicememory_mobile/lib/startup/archive_me_startup.dart"),
    "utf8",
  );
  const appServicesSource = await readFile(
    path.join(root, "apps/voicememory_mobile/lib/services/app_services.dart"),
    "utf8",
  ).catch(() => "");
  const capabilitySource = await readFile(
    path.join(root, "apps/voicememory_mobile/lib/core/config/v1_capability_registry.dart"),
    "utf8",
  );
  const pubspecSource = await readFile(path.join(root, "apps/voicememory_mobile/pubspec.yaml"), "utf8");
  const androidManifest = await readFile(
    path.join(root, "apps/voicememory_mobile/android/app/src/main/AndroidManifest.xml"),
    "utf8",
  );
  const androidGradle = await readFile(
    path.join(root, "apps/voicememory_mobile/android/app/build.gradle.kts"),
    "utf8",
  );
  const iosInfo = await readFile(
    path.join(root, "apps/voicememory_mobile/ios/Runner/Info-Release.plist"),
    "utf8",
  );
  const iosEntitlements = await readFile(
    path.join(root, "apps/voicememory_mobile/ios/Runner/Runner-Release.entitlements"),
    "utf8",
  );
  const iosProject = await readFile(
    path.join(root, "apps/voicememory_mobile/ios/Runner.xcodeproj/project.pbxproj"),
    "utf8",
  );

  const graph = await importGraph(root, contract.product.entryPoints);
  const catalog = routeCatalogValues(catalogSource);
  const sourceRoutes = {
    primary: constCollection(catalogSource, "primaryRoutes", catalog),
    secondary: constCollection(productSource, "secondaryRoutes", catalog),
    flows: constCollection(productSource, "flowRoutes", catalog),
    allowedPrefixes: constCollection(productSource, "allowedRoutePrefixes", catalog),
    explicitlyExcluded: constCollection(productSource, "excludedConsumerRoutes", catalog),
  };
  const routerLiteralRoutes = unique(
    [...routerSource.matchAll(/path:\s*'([^']+)'/g)].map((match) => match[1]),
  );
  const routerRouteExpressions = unique(
    [...routerSource.matchAll(/\bpath:\s*([^,\n]+)/g)].map((match) => match[1].trim()),
  );

  const backendFiles = await filesUnder(
    path.join(root, "app/api"),
    (file) => file.endsWith(`${path.sep}route.ts`),
  );
  const backendRoutes = backendFiles.map((file) => routeFileToApi(root, file)).sort();
  const consumerWebPages = (await filesUnder(
    path.join(root, "app"),
    (file) => file.endsWith(`${path.sep}page.tsx`),
  )).map((file) => relativePath(root, file));
  const appClientFiles = (await filesUnder(
    path.join(root, "app"),
    (file) => file.endsWith("Client.tsx"),
  )).map((file) => relativePath(root, file));
  const legacyWebSources = await Promise.all(
    (await filesUnder(
      path.join(root, "experiments/archive_me_legacy_web"),
      (file) => /\.(?:ts|tsx)$/.test(file),
    )).map((file) => readFile(file, "utf8")),
  );
  const legacyWebImports = new Set(
    legacyWebSources.flatMap((source) =>
      [...source.matchAll(/from\s+['"]@\/(app\/[^'"]+)['"]/g)].map(
        (match) => `${match[1]}.tsx`,
      ),
    ),
  );
  const appClientClassifications = appClientFiles.map((file) => ({
    file,
    classification: legacyWebImports.has(file)
      ? "EXPERIMENTAL_SUPPORT"
      : "DORMANT_UNREACHABLE",
  }));
  const mobileApiReferences = unique(
    [...graph.sourceByFile.values()].flatMap((source) =>
      [...source.matchAll(/['"]((?:\/api\/)[A-Za-z0-9_./${}-]+)['"]/g)].map((match) =>
        match[1].replace(/\$[A-Za-z{][^/}"']*/g, ":id"),
      ),
    ),
  );

  const declaredPlugins = dependencyNames(pubspecSource);
  const pluginClassification = Object.fromEntries(
    Object.entries(contract.plugins).flatMap(([classification, plugins]) =>
      plugins.map((plugin) => [plugin, classification]),
    ),
  );
  const pluginRows = declaredPlugins.map((name) => ({
    name,
    classification: pluginClassification[name] ?? "UNCLASSIFIED",
    importedFromEntrypoint: graph.packageImports.includes(name),
  }));

  const discoveredServices = unique(
    [...`${startupSource}\n${appServicesSource}`.matchAll(/\b([A-Z][A-Za-z0-9]+(?:Service|Scheduler|Controller|Store|Paths))\b/g)]
      .map((match) => match[1]),
  );
  const androidPermissions = positiveAndroidPermissions(androidManifest);
  const iosUsageDescriptions = plistKeys(iosInfo).filter(
    (key) => key.startsWith("NS") && key.endsWith("UsageDescription"),
  );
  const iosEntitlementKeys = plistKeys(iosEntitlements);
  const testFiles = (await filesUnder(
    path.join(root, "apps/voicememory_mobile/test"),
    (file) => file.endsWith("_test.dart"),
  )).map((file) => relativePath(root, file));
  const testGraph = await importGraph(root, testFiles);
  const productionDartFiles = (await filesUnder(
    path.join(root, "apps/voicememory_mobile/lib"),
    (file) => file.endsWith(".dart"),
  )).map((file) => relativePath(root, file));
  const shippingFiles = new Set(graph.reachableFiles);
  const testReachableFiles = new Set(testGraph.reachableFiles);
  const shippingReachable = productionDartFiles.filter((file) => shippingFiles.has(file));
  const testOnly = productionDartFiles.filter(
    (file) => !shippingFiles.has(file) && testReachableFiles.has(file),
  );
  const dormantUnreachable = productionDartFiles.filter(
    (file) => !shippingFiles.has(file) && !testReachableFiles.has(file),
  );

  const identities = {
    displayName: iosInfo.match(/<key>CFBundleDisplayName<\/key>\s*<string>([^<]+)<\/string>/)?.[1] ?? null,
    androidApplicationId: androidGradle.match(/applicationId\s*=\s*"([^"]+)"/)?.[1] ?? null,
    iosBundleIds: unique([...iosProject.matchAll(/PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/g)].map((match) => match[1])),
    urlSchemes: unique([
      ...iosInfo.matchAll(/<string>([a-z][a-z0-9+.-]+)<\/string>/g),
    ].map((match) => match[1]).filter((value) => value === "archiveme")),
  };

  const violations = [];
  if (contract.schemaVersion !== 1) violations.push("schemaVersion must be 1");
  if (consumerWebPages.length) {
    violations.push(
      `consumer web pages remain in API-only backend: ${consumerWebPages.join(", ")}`,
    );
  }
  if (graph.unresolvedLocalImports.length) {
    violations.push(
      `unresolved Dart imports reachable from the release entry point: ${
        graph.unresolvedLocalImports
          .map((row) => `${row.from} -> ${row.expected}`)
          .join(", ")
      }`,
    );
  }
  if (testGraph.unresolvedLocalImports.length) {
    violations.push(
      `unresolved Dart imports reachable from Flutter tests: ${
        testGraph.unresolvedLocalImports
          .map((row) => `${row.from} -> ${row.expected}`)
          .join(", ")
      }`,
    );
  }
  if (!sameMembers(contract.routes.primary, sourceRoutes.primary) || contract.routes.primary.length !== 4) {
    violations.push("primary route allowlist drifted from RouteCatalog.primaryRoutes");
  }
  for (const key of ["secondary", "flows", "allowedPrefixes", "explicitlyExcluded"]) {
    if (!sameMembers(contract.routes[key], sourceRoutes[key])) {
      violations.push(`${key} route allowlist drifted from ArchiveMeV1ProductContract`);
    }
  }
  const routeOverlap = contract.routes.explicitlyExcluded.filter((route) =>
    [...contract.routes.primary, ...contract.routes.secondary, ...contract.routes.flows].includes(route),
  );
  if (routeOverlap.length) violations.push(`routes both allowed and excluded: ${routeOverlap.join(", ")}`);

  const missingBackend = contract.backendApis.required.filter((route) => !backendRoutes.includes(route));
  if (missingBackend.length) violations.push(`required backend routes missing: ${missingBackend.join(", ")}`);

  const unclassifiedPlugins = pluginRows.filter((row) => row.classification === "UNCLASSIFIED");
  if (unclassifiedPlugins.length) {
    violations.push(`unclassified Flutter dependencies: ${unclassifiedPlugins.map((row) => row.name).join(", ")}`);
  }
  const classifiedButUndeclared = Object.keys(pluginClassification).filter(
    (plugin) => !declaredPlugins.includes(plugin),
  );
  if (classifiedButUndeclared.length) {
    violations.push(`contract plugins absent from pubspec: ${classifiedButUndeclared.join(", ")}`);
  }
  if (!sameMembers(contract.permissions.android, androidPermissions)) {
    violations.push("Android source manifest positive permissions drifted from contract");
  }
  if (!sameMembers(contract.permissions.iosUsageDescriptions, iosUsageDescriptions)) {
    violations.push("iOS Release usage descriptions drifted from contract");
  }
  if (!sameMembers(contract.permissions.iosEntitlements, iosEntitlementKeys)) {
    violations.push("iOS Release entitlements drifted from contract");
  }
  const registryAndroid = unique(
    [...capabilitySource.matchAll(/'(android\.permission\.[A-Z0-9_]+|com\.android\.vending\.BILLING)'/g)]
      .map((match) => match[1]),
  );
  const registryIos = unique(
    [...capabilitySource.matchAll(/'(NS[A-Za-z]+UsageDescription)'/g)].map((match) => match[1]),
  );
  if (!sameMembers(contract.permissions.android, registryAndroid)) {
    violations.push("V1CapabilityRegistry Android allowlist drifted from contract");
  }
  if (!sameMembers(contract.permissions.iosUsageDescriptions, registryIos)) {
    violations.push("V1CapabilityRegistry iOS allowlist drifted from contract");
  }
  if (
    identities.displayName !== contract.identities.displayName ||
    identities.androidApplicationId !== contract.identities.androidApplicationId ||
    !identities.iosBundleIds.includes(contract.identities.iosBundleId) ||
    !sameMembers(identities.urlSchemes, contract.identities.urlSchemes)
  ) {
    violations.push("release identity drifted from contract");
  }
  const classificationNames = contract.moduleClassifications.map((row) => row.classification);
  if (!sameMembers(classificationNames, CLASSIFICATIONS)) {
    violations.push("module classifications must contain each V1 disposition exactly once");
  }
  const duplicateModules = Object.entries(
    contract.moduleClassifications
      .flatMap((row) => row.modules)
      .reduce((counts, module) => ({ ...counts, [module]: (counts[module] ?? 0) + 1 }), {}),
  ).filter(([, count]) => count > 1);
  if (duplicateModules.length) {
    violations.push(`modules have multiple classifications: ${duplicateModules.map(([name]) => name).join(", ")}`);
  }
  const missingModules = [];
  for (const row of contract.moduleClassifications) {
    if (["REMOVE", "EXPERIMENTAL_ISOLATED"].includes(row.classification)) continue;
    for (const module of row.modules) {
      if (!(await exists(path.join(root, module)))) missingModules.push(module);
    }
  }
  if (missingModules.length) violations.push(`classified modules missing: ${missingModules.join(", ")}`);
  const releaseExcludedModules = contract.moduleClassifications
    .filter((row) => ["REMOVE", "EXPERIMENTAL_ISOLATED"].includes(row.classification))
    .flatMap((row) => row.modules);
  const reachableExcludedModules = releaseExcludedModules.filter((module) =>
    graph.reachableFiles.some(
      (file) => file === module || file.startsWith(`${module}/`),
    ),
  );
  if (reachableExcludedModules.length) {
    violations.push(
      `removed or isolated modules remain in the shipping import graph: ${reachableExcludedModules.join(", ")}`,
    );
  }
  const missingGuardTests = [];
  for (const test of contract.architectureGuardTests) {
    if (!(await exists(path.join(root, test)))) missingGuardTests.push(test);
  }
  if (missingGuardTests.length) violations.push(`architecture guard tests missing: ${missingGuardTests.join(", ")}`);
  const moduleRows = await Promise.all(contract.moduleClassifications.map(async (row) => ({
    ...row,
    dispositions: await Promise.all(row.modules.map(async (module) => ({
      module,
      exists: await exists(path.join(root, module)),
      shippingReachableFiles: filesWithin(shippingReachable, module).length,
      testOnlyFiles: filesWithin(testOnly, module).length,
      dormantUnreachableFiles: filesWithin(dormantUnreachable, module).length,
    }))),
  })));

  return {
    schemaVersion: 1,
    contractId: contract.contractId,
    generatedBy: "node scripts/archive-me-v1-release-architecture.mjs",
    status: violations.length ? "FAIL" : "PASS",
    violations,
    entryPoints: {
      configured: contract.product.entryPoints,
      reachableDartFileCount: graph.reachableFiles.length,
      reachableDartFiles: graph.reachableFiles,
    },
    routes: {
      allowlist: contract.routes,
      sourceDerived: sourceRoutes,
      routerDeclaredLiteralCount: routerLiteralRoutes.length,
      routerDeclaredLiterals: routerLiteralRoutes,
      routerRouteExpressions,
    },
    imports: {
      edgeCount: graph.edges.length,
      edges: graph.edges,
      packageImports: graph.packageImports,
      unresolvedLocalImports: graph.unresolvedLocalImports,
    },
    services: {
      contract: contract.services,
      discoveredInStartupAndAppServices: discoveredServices,
    },
    backendApis: {
      required: contract.backendApis.required,
      declaredCount: backendRoutes.length,
      declared: backendRoutes,
      referencedByReachableDart: mobileApiReferences,
      backendOnlyPrefixes: contract.backendApis.backendOnlyPrefixes,
    },
    webSurface: {
      consumerPageFiles: consumerWebPages,
      clientClassifications: appClientClassifications,
    },
    plugins: {
      declaredCount: declaredPlugins.length,
      rows: pluginRows,
    },
    permissions: {
      contract: contract.permissions,
      discovered: {
        androidPositiveSourceManifest: androidPermissions,
        iosReleaseUsageDescriptions: iosUsageDescriptions,
        iosReleaseEntitlements: iosEntitlementKeys,
      },
    },
    identities: {
      contract: contract.identities,
      discovered: identities,
    },
    tests: {
      architectureGuards: contract.architectureGuardTests,
      discoveredCount: testFiles.length,
      rows: classifyTests(testFiles),
    },
    reachabilityInventory: {
      productionDartFileCount: productionDartFiles.length,
      shippingReachable: {
        count: shippingReachable.length,
        files: shippingReachable,
      },
      testOnly: {
        count: testOnly.length,
        files: testOnly,
      },
      dormantUnreachable: {
        count: dormantUnreachable.length,
        files: dormantUnreachable,
      },
      testGraphUnresolvedLocalImports: testGraph.unresolvedLocalImports,
    },
    modules: moduleRows,
  };
}

export function renderReachabilityMarkdown(report) {
  return `# ArchiveMe V1 reachability report

Generated by \`${report.generatedBy}\` from
\`${CONTRACT_PATH}\`. This report follows the actual transitive Dart import
graph from the shipping entry point. A hidden route or disabled flag does not
remove an imported module from the release graph.

## Guard result

**${report.status}** — ${report.violations.length} violation(s).

${report.violations.length ? markdownList(report.violations) : "No architecture-contract violations."}

## Release entry point and import graph

- Flutter entry point: \`${report.entryPoints.configured[0]}\`
- Transitively imported Dart files: ${report.entryPoints.reachableDartFileCount}
- Local import/export edges: ${report.imports.edgeCount}
- Imported package dependencies: ${report.imports.packageImports.length}

The complete file and edge maps are in \`${REPORT_PATH}\`.

## Production Dart disposition

- Shipping-reachable: ${report.reachabilityInventory.shippingReachable.count}
- Test-only: ${report.reachabilityInventory.testOnly.count}
- Dormant and unreachable from shipping or tests: ${report.reachabilityInventory.dormantUnreachable.count}

These classifications come from import graphs rooted at the shipping entry point
and every Flutter test entry point. They do not infer reachability from names.

### Test-only production files
${markdownList(report.reachabilityInventory.testOnly.files)}

### Dormant, unreachable production files
${markdownList(report.reachabilityInventory.dormantUnreachable.files)}

## Reachable V1 routes

### Four primary destinations
${markdownList(report.routes.allowlist.primary)}

### Secondary surfaces
${markdownList(report.routes.allowlist.secondary)}

### Onboarding and acquisition flows
${markdownList(report.routes.allowlist.flows)}

Allowed dynamic prefixes: ${report.routes.allowlist.allowedPrefixes.map((value) => `\`${value}\``).join(", ")}.
The router declares ${report.routes.routerDeclaredLiteralCount} literal route
paths. Every registered production route must appear in the contract.

## Required backend

${markdownList(report.backendApis.required)}

The repository currently declares ${report.backendApis.declaredCount} backend routes. Internal,
analytics, metrics, and resurfacing-only route families remain backend-only.

## Web route and client disposition

- Consumer web page routes in the API-only backend: ${report.webSurface.consumerPageFiles.length}
- Residual client modules: ${report.webSurface.clientClassifications.length}

${report.webSurface.clientClassifications.length
    ? report.webSurface.clientClassifications
      .map((row) => `- \`${row.file}\` — ${row.classification}`)
      .join("\n")
    : "- None"}

## Native release envelope

- Android permissions: ${report.permissions.contract.android.map((value) => `\`${value}\``).join(", ")}
- iOS usage descriptions: ${report.permissions.contract.iosUsageDescriptions.map((value) => `\`${value}\``).join(", ")}
- iOS explicit entitlements: none
- Android application ID: \`${report.identities.contract.androidApplicationId}\`
- iOS bundle ID: \`${report.identities.contract.iosBundleId}\`
- URL scheme: \`${report.identities.contract.urlSchemes[0]}\`

## Reproduce

\`\`\`bash
node scripts/archive-me-v1-release-architecture.mjs --check
node --test scripts/archive-me-v1-release-architecture.test.mjs
\`\`\`
`;
}

export function renderRemovalManifest(report) {
  const sections = report.modules.map(
    (row) => {
      const modules = row.dispositions.map((entry) => {
        const classifiedFileCount =
          entry.shippingReachableFiles +
          entry.testOnlyFiles +
          entry.dormantUnreachableFiles;
        const state = !entry.exists
          ? "absent"
          : classifiedFileCount === 0
            ? "empty or non-Dart boundary"
            : "present";
        const reachability =
          `shipping ${entry.shippingReachableFiles}, test-only ${entry.testOnlyFiles}, ` +
          `dormant ${entry.dormantUnreachableFiles}`;
        return `- \`${entry.module}\` — ${state}; ${reachability}`;
      });
      return `## ${row.classification}\n\n${modules.length ? modules.join("\n") : "- None"}`;
    },
  );
  return `# ArchiveMe V1 removal manifest

This is the executable disposition manifest for the shipping graph.
\`RETAIN\` is required by V1, \`CONSOLIDATE\` has a temporary extraction
boundary, and \`REMOVE\` or \`EXPERIMENTAL_ISOLATED\` modules fail the
architecture guard when transitively imported by the shipping entry point.

${sections.join("\n\n")}
`;
}

async function writeArtifacts(root, report) {
  await mkdir(path.dirname(path.join(root, REPORT_PATH)), { recursive: true });
  await writeFile(path.join(root, REPORT_PATH), `${JSON.stringify(report, null, 2)}\n`);
  await writeFile(path.join(root, MARKDOWN_PATH), renderReachabilityMarkdown(report));
  await writeFile(path.join(root, REMOVAL_PATH), renderRemovalManifest(report));
}

async function main() {
  const check = process.argv.includes("--check");
  const report = await buildArchitectureReport(DEFAULT_ROOT);
  if (check) {
    const expectedReport = `${JSON.stringify(report, null, 2)}\n`;
    const expectedMarkdown = renderReachabilityMarkdown(report);
    const expectedRemoval = renderRemovalManifest(report);
    const stale = [];
    for (const [relative, expected] of [
      [REPORT_PATH, expectedReport],
      [MARKDOWN_PATH, expectedMarkdown],
      [REMOVAL_PATH, expectedRemoval],
    ]) {
      const actual = await readFile(path.join(DEFAULT_ROOT, relative), "utf8").catch(() => null);
      if (actual !== expected) stale.push(relative);
    }
    if (stale.length) report.violations.push(`generated artifacts are stale: ${stale.join(", ")}`);
  } else {
    await writeArtifacts(DEFAULT_ROOT, report);
  }
  if (report.violations.length) {
    console.error(report.violations.map((violation) => `- ${violation}`).join("\n"));
    process.exitCode = 1;
    return;
  }
  console.log(
    `ArchiveMe V1 architecture guard passed: ${report.entryPoints.reachableDartFileCount} Dart files, ` +
      `${report.routes.allowlist.primary.length} primary routes, ${report.backendApis.required.length} required APIs.`,
  );
}

if (process.argv[1] && path.resolve(process.argv[1]) === SCRIPT_PATH) {
  await main();
}
