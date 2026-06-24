import type { Metadata } from "next";
import "./globals.css";
import SessionExpiredOverlay from "@/components/SessionExpiredOverlay";

export const metadata: Metadata = {
  title: "Royal HRMS",
  description: "Royal Human Resource Management System — By SRIA",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" style={{ height: "100%" }} suppressHydrationWarning>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/tabler-icons.min.css"
        />
      </head>
      <body style={{ minHeight: "100vh" }} suppressHydrationWarning>
        {children}
        <SessionExpiredOverlay />
      </body>
    </html>
  );
}
