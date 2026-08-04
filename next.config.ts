import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  serverExternalPackages: ["pg"],
  turbopack: {
    ignoreIssue: [
      // Flutter generates TypeScript bindings in these directories. They are
      // excluded from the web compiler and should not produce workspace
      // filesystem-pattern or unresolved client-binding warnings.
      { path: "**/apps/voicememory_mobile/build/**" },
      { path: "**/apps/voicememory_mobile/ios/.symlinks/**" },
      { path: "**/apps/voicememory_mobile/macos/Flutter/ephemeral/**" },
      { path: "**/apps/voicememory_mobile/.dart_tool/**" },
      {
        path: /lib\/mobile\/(?:flutter-repo|release-evidence)\.ts$/,
        title: /file pattern/i,
      },
      {
        path: "**/lib/internal/design-consistency-file-audit.ts",
        title: /file pattern/i,
      },
      {
        path: "**/next.config.ts",
        title: /unexpected file in NFT list/i,
      },
    ],
  },
};

export default nextConfig;
