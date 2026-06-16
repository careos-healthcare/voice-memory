import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "ArchiveMe",
    short_name: "ArchiveMe",
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
        name: "Continue speaking",
        short_name: "Continue",
        url: "/record?source=reflex",
        description: "Resume speaking without the homepage",
      },
      {
        name: "Return to this",
        short_name: "Return",
        url: "/record?source=return",
        description: "Record with return context — add quote in-app if needed",
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
