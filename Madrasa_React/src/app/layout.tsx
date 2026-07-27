import './globals.css';
import type { Metadata } from 'next';
import Sidebar from '@/components/Sidebar';
import { ThemeProvider } from '@/context/ThemeContext';

export const metadata: Metadata = {
  title: 'Madrasa Hub',
  description: 'Multi-Tenant Madrasa Management System',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ur" dir="rtl" suppressHydrationWarning>
      <body suppressHydrationWarning className="font-urdu bg-slate-50 text-slate-800 dark:bg-slate-900 dark:text-slate-100 flex h-screen overflow-hidden print:h-auto print:overflow-visible print:block transition-colors">
        <ThemeProvider>
          <Sidebar />
          <main className="flex-1 overflow-y-auto print:overflow-visible print:block bg-slate-50 dark:bg-slate-900 relative transition-colors">
            {children}
          </main>
        </ThemeProvider>
      </body>
    </html>
  );
}
