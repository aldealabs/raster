import type { Metadata } from "next";
import "@fontsource-variable/inter/wght.css";
import "@fontsource-variable/inter/wght-italic.css";
import "./globals.css";
import { ThemeProvider } from "@/components/theme-provider";
import { buildThemeBootstrapScript } from "@/lib/theme-preference";

export const metadata: Metadata = {
  title: {
    default: "Raster Documentation",
    template: "%s — Raster Documentation",
  },
  description:
    "Documentation for Raster, the Metal image processing framework continued from MetalPetal.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      data-scroll-behavior="smooth"
      className="h-full subpixel-antialiased"
    >
      <head>
        <link rel="preconnect" href="https://cdn.aldealabs.com" crossOrigin="anonymous" />
        <link
          rel="preload"
          href="https://cdn.aldealabs.com/fonts/aldea/1.0.0/AldeaSansDisplay-Variable.woff2"
          as="font"
          type="font/woff2"
          crossOrigin="anonymous"
        />
        <link
          rel="preload"
          href="https://cdn.aldealabs.com/fonts/aldea/1.0.0/AldeaTech-Variable.woff2"
          as="font"
          type="font/woff2"
          crossOrigin="anonymous"
        />
        <script dangerouslySetInnerHTML={{ __html: buildThemeBootstrapScript() }} />
      </head>
      <body className="min-h-full">
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  );
}
