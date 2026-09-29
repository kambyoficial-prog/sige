import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "SIGE", template: "%s | SIGE" },
  description: "Sistema Integrado de Gestão Escolar",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt">
      <body>{children}</body>
    </html>
  );
}
