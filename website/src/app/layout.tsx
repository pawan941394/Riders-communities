import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://ridewithgarv.com"),
  title: "Ride with Garv | Rider Community App",
  description:
    "Ride with Garv is a rider community app for posting work issues, getting rider replies, EV charging, rent EV plans, and buy EV support.",
  alternates: {
    canonical: "/",
  },
  icons: {
    icon: [
      {
        url: "/icons/icon.png",
        type: "image/png",
      },
      {
        url: "/icon.png",
        type: "image/png",
      },
    ],
    shortcut: "/icons/icon.png",
    apple: [
      {
        url: "/icons/icon.png",
        type: "image/png",
      },
    ],
  },
  openGraph: {
    title: "Ride with Garv | Rider Community App",
    description:
      "Post rider problems, get community replies, and explore EV charging, rent, and buy options.",
    url: "https://ridewithgarv.com",
    siteName: "Ride with Garv",
    images: [
      {
        url: "/landing/hero-banner.png",
        width: 1536,
        height: 1024,
        alt: "Ride with Garv rider community app",
      },
    ],
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Ride with Garv | Rider Community App",
    description:
      "A rider-first community app for delivery workers, issue posts, support, and EV help.",
    images: ["/landing/hero-banner.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${geistSans.variable} ${geistMono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
