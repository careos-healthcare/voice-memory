> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Flutter V1 release pipeline

`.github/workflows/build_and_deploy.yml` is the only authoritative production
release workflow. It is manually dispatched, uses the protected `production`
environment for store credentials, and orders the release as follows:

1. validate and build the credential-free production backend;
2. run backend migration, billing, account-deletion, transcription, sync, and
   monetized-usage contracts;
3. analyze and test Flutter;
4. build, audit, preserve, and upload Android and iOS artifacts.

`.github/workflows/flutter_ci.yml` remains pull-request CI. It is not a release
workflow and cannot upload or deploy production artifacts.

## Backend authority and deployment

`config/release/backend-capabilities.json` is the route and release-dependency
authority. Every `app/api/**/route.ts` handler must belong to exactly one
capability group. A new, removed, or duplicate classification fails
`npm run validate:release-graph`.

The backend deployment artifact is the root `Dockerfile`. It runs
`npm run build:backend`, which stages only API handlers and backend dependencies
under `.backend-release`, builds that isolated Next.js application, verifies its
compiled route manifest, and bundles the custom HTTP/WebSocket entry point.
Production starts it with `npm start`.

Deployment responsibilities are deliberately separated:

- **Code-owned and credential-free:** locked dependency install, migration
  structure validation, backend contract tests, API-only Next.js build, custom
  server bundle, and Docker image build.
- **Environment-owned:** run SQL migrations against the selected production
  database before replacing the running backend image.
- **Secret-owned:** database, OpenAI/Gemini, email, Firebase, Stripe,
  RevenueCat, internal-cron, and mobile signing/store credentials are injected
  by the deployment platform or protected GitHub environment. They are not
  required for production build validation.
- **Release dependency:** Android and iOS store jobs cannot start until backend
  validation succeeds. `VOICE_MEMORY_API_BASE_URL` must identify the deployed
  backend candidate before either mobile upload is approved.

The workflow builds and validates the deployable backend image but does not
guess a hosting-provider command. Promoting that image and applying live
migrations remain explicit environment operations until a single hosting target
is configured.

## Release graph boundary

The release backend includes all allowed Flutter-facing APIs, WebSocket
upgrades, billing webhooks, and operational routes listed in the capability
policy. It excludes customer Next.js pages, `components`, `public`, Flutter and
Capacitor/native shells, and repository-level `android`/`ios` projects.

Run:

```sh
npm run validate:release-graph
npm run build:backend
```

The second command runs the guard again against the compiled artifact. The
guard rejects unclassified handlers, duplicate release workflows/scripts,
customer routes in the Next.js manifest, or excluded client-shell paths in
release traces.

## Platform references

- Android: `apps/voicememory_mobile/docs/ANDROID_RELEASE_CHECKLIST.md`
- iOS: `apps/voicememory_mobile/docs/IOS_RELEASE_CHECKLIST.md`
- Release decision: `apps/voicememory_mobile/docs/RELEASE_READINESS.md`
- RevenueCat manual evidence:
  `apps/voicememory_mobile/docs/REVENUECAT_RELEASE_CHECKLIST.md`

