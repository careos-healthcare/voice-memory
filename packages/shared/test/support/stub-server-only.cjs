"use strict";
// Test-only: "server-only" throws unconditionally outside Next.js's own
// bundler (see https://github.com/vercel/next.js/issues/60038). This
// preload redirects any require("server-only") / require("client-only")
// to an empty stub for the duration of this test run only — it never
// touches the real package used by actual app builds.
const Module = require("node:module");
const path = require("node:path");

const STUB_PATH = path.join(__dirname, "__stub__server-only.js");

const originalResolveFilename = Module._resolveFilename;
Module._resolveFilename = function (request, parent, isMain, options) {
  if (request === "server-only" || request === "client-only") {
    return STUB_PATH;
  }
  return originalResolveFilename.call(this, request, parent, isMain, options);
};

if (!require.cache[STUB_PATH]) {
  const stubModule = new Module(STUB_PATH, null);
  stubModule.filename = STUB_PATH;
  stubModule.loaded = true;
  stubModule.exports = {};
  require.cache[STUB_PATH] = stubModule;
}
