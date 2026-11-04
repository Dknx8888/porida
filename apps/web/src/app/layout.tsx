import type { Metadata } from "next";
import { Inter, Geist_Mono } from "next/font/google";
import "./globals.css";
import { AppShell } from "@/components/layout/app-shell";
import { ThemeProvider } from "@/providers/theme-provider";
import { QueryProvider } from "@/providers/query-provider";


const inter = Inter({
    variable: "--font-inter",
    subsets: ["latin"],
    display: 'swap' // Use placeholder until font loads
});

const geistMono = Geist_Mono({
    variable: "--font-geist-mono",
    subsets: ["latin"],
    display: 'swap' 
});

export const metadata: Metadata = {
    title: "Portfolios | Porida",
    description: "Portfolio List",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
        lang="en"
        suppressHydrationWarning
        className={`${inter.variable} ${geistMono.variable} h-full antialiased`}
    >
            <body className="min-h-full flex flex-col">
                <ThemeProvider>
                    <QueryProvider>
                        <AppShell>{children}</AppShell>
                    </QueryProvider>
                </ThemeProvider>
            </body>
    </html>
  );
}
