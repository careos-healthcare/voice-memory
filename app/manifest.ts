import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "VoiceMemory",
    short_name: "VoiceMemory",
    description:
      "Private voice reflections — local-first, resurfaced in your own words.",
    start_url: "/",
    scope: "/",
    display: "standalone",
    orientation: "portrait-primary",
    background_color: "#09090b",
    theme_color: "#09090b",
    categories: ["lifestyle", "health"],
    shortcuts: [
      {
        name: "Record now",
        short_name: "Record",
        url: "/record",
        description: "Open directly to recording",
      },
      {
        name: "Return to this",
        short_name: "Return",
        url: "/record?source=return",
        description: "Record with return context",
      },
    ],
    icons: [
      {
        src: "/icon",
        sizes: "512x512",
        type: "image/png",
        purpose: "any",
      },
      {
        src: "/apple-icon",
        sizes: "180x180",
        type: "image/png",
      },
    ],
  };
}
