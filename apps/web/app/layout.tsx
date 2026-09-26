import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono, Newsreader } from "next/font/google";

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

const newsreader = Newsreader({
  variable: "--font-newsreader",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Thoughtprint — Save the moment. See what returns.",
  description:
    "Thoughtprint is a private mobile app for recording real moments and revisiting them in your own words over time.",
  applicationName: "Thoughtprint",
  appleWebApp: {
    capable: true,
    title: "Thoughtprint",
    statusBarStyle: "black-translucent",
  },
  formatDetection: {
    telephone: false,
  },
};

export const viewport: Viewport = {
  themeColor: "#FDFBF7",
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
        className={`${geistSans.variable} ${geistMono.variable} ${newsreader.variable} min-h-screen-mobile bg-background antialiased text-foreground`}
      >
        <script
          dangerouslySetInnerHTML={{
            __html:
              "if ('serviceWorker' in navigator) { navigator.serviceWorker.getRegistrations().then(regs => regs.forEach(r => r.unregister())); }",
          }}
        />
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
