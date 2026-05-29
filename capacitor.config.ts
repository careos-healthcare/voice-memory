import type { CapacitorConfig } from "@capacitor/cli";

/**
 * Capacitor loads the production Next.js deployment by default.
 * Local dev: CAPACITOR_SERVER_URL=http://localhost:3000 npm run mobile:sync
 */
const serverUrl =
  process.env.CAPACITOR_SERVER_URL?.trim() ||
  process.env.NEXT_PUBLIC_APP_URL?.trim() ||
  "https://voicememory.app";

const isLocalDev =
  serverUrl.includes("localhost") || serverUrl.includes("127.0.0.1");

const config: CapacitorConfig = {
  appId: "com.voicememory.app",
  appName: "VoiceMemory",
  webDir: "mobile/web",
  server: {
    url: serverUrl,
    cleartext: isLocalDev,
    androidScheme: isLocalDev ? "http" : "https",
  },
  ios: {
    contentInset: "automatic",
    scheme: "VoiceMemory",
  },
  android: {
    allowMixedContent: isLocalDev,
  },
  plugins: {
    CapacitorHttp: {
      enabled: true,
    },
  },
};

export default config;
