import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";

import "./globals.css";
import { AppProviders } from "./providers";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "ArchiveMe — Private voice reflections",
  description:
    "Save small moments when something stands out. ArchiveMe turns them into a private timeline of what appeared, what returned, what you corrected, and what still matters now. No daily journal required.",
  applicationName: "ArchiveMe",
  appleWebApp: {
    capable: true,
    title: "ArchiveMe",
    statusBarStyle: "black-translucent",
  },
  formatDetection: {
    telephone: false,
  },
};

export const viewport: Viewport = {
  themeColor: "#09090b",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" data-tone="deep-dark">
      <body
        className={`${geistSans.variable} ${geistMono.variable} min-h-screen-mobile bg-background antialiased text-foreground`}
      >
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
