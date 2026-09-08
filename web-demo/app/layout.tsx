import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "澜礁 · 海缸水质助手 Demo",
  description: "离线优先的海缸水质检测、趋势和维护提醒交互原型。",
  openGraph: {
    title: "澜礁 · 海缸水质助手",
    description: "记录水质变化，照顾每一座小小海洋。",
    type: "website",
    images: [{ url: "/og.png", width: 1730, height: 909, alt: "澜礁海缸水质助手" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "澜礁 · 海缸水质助手",
    description: "离线优先的海缸水质检测与维护提醒 Demo。",
    images: ["/og.png"],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
