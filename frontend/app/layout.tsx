import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import Link from "next/link";
import { Factory, GraduationCap, Home } from "lucide-react";
import { HITLBanner } from "@/components/hitl-banner";
import "./globals.css";

const geistSans = Geist({ variable: "--font-geist-sans", subsets: ["latin"] });
const geistMono = Geist_Mono({ variable: "--font-geist-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Factory · Panel de control",
  description: "Planta autónoma de fabricación de conexiones · Perlatours",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es" className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col bg-zinc-950 text-zinc-100">
        <header className="sticky top-0 z-40 border-b border-zinc-800 bg-zinc-950/80 backdrop-blur-xl">
          <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-6 py-3">
            <Link href="/" className="flex items-center gap-3">
              <div className="grid h-9 w-9 place-items-center rounded-lg bg-gradient-to-br from-cyan-500 to-emerald-500 text-zinc-950">
                <Factory className="h-5 w-5" />
              </div>
              <div>
                <div className="text-sm font-semibold tracking-tight">Factory</div>
                <div className="text-[11px] text-zinc-400">Perlatours · Planta de conexiones</div>
              </div>
            </Link>
            <nav className="flex items-center gap-1 text-sm">
              <Link
                href="/"
                className="flex items-center gap-2 rounded-md px-3 py-1.5 text-zinc-300 hover:bg-zinc-900 hover:text-zinc-50"
              >
                <Home className="h-4 w-4" /> Piso de planta
              </Link>
              <Link
                href="/learning"
                className="flex items-center gap-2 rounded-md px-3 py-1.5 text-zinc-300 hover:bg-zinc-900 hover:text-zinc-50"
              >
                <GraduationCap className="h-4 w-4" /> Aprendizaje
              </Link>
            </nav>
          </div>
        </header>

        <main className="flex-1 bg-grid">
          <div className="mx-auto max-w-7xl px-6 py-6">
            <HITLBanner />
            {children}
          </div>
        </main>

        <footer className="border-t border-zinc-800 bg-zinc-950 py-4">
          <div className="mx-auto max-w-7xl px-6 text-xs text-zinc-500 flex items-center justify-between">
            <span>Perlatours/factory · Panel solo lectura (factory_reader · SELECT only)</span>
            <span>Operar = skills Claude Code · Mirar = aquí</span>
          </div>
        </footer>
      </body>
    </html>
  );
}
