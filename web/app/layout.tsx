import type { Metadata } from "next";
import "./globals.css";
import ThemeScript from "@/components/ThemeScript";
import ToastViewport from "@/components/common/ToastViewport";
import { AppShellProvider } from "@/context/AppShellContext";
import { I18nClientBridge } from "@/i18n/I18nClientBridge";

// Use CSS system font stacks instead of Google Fonts
// This avoids build-time network dependency on Google Fonts CDN
const fontSansClass = "";  // --font-sans is set via globals.css
const fontSerifClass = ""; // --font-serif is set via globals.css

export const metadata: Metadata = {
  title: "DeepTutor",
  description: "Agent-native intelligent learning companion",
  icons: {
    icon: [
      { url: "/favicon-16x16.png", sizes: "16x16", type: "image/png" },
      { url: "/favicon-32x32.png", sizes: "32x32", type: "image/png" },
    ],
    apple: "/apple-touch-icon.png",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${fontSansClass} ${fontSerifClass}`}>
        <ThemeScript />
        <AppShellProvider>
          <I18nClientBridge>{children}</I18nClientBridge>
        </AppShellProvider>
        <ToastViewport />
      </body>
    </html>
  );
}
