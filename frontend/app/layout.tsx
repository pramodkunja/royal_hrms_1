import type { Metadata } from "next";
import { Poppins } from "next/font/google";
import "./globals.css";
import SessionExpiredOverlay from "@/components/SessionExpiredOverlay";

const poppins = Poppins({
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700"],
  display: "swap",
});

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
        <link
          rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/tabler-icons.min.css"
        />
      </head>
      <body className={poppins.className} style={{ minHeight: "100vh" }} suppressHydrationWarning>
        {children}
        <SessionExpiredOverlay />
      </body>
    </html>
  );
}
