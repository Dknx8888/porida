"use client";

import { useState, type ReactNode } from 'react';
import { Header } from './header';
import { Sidebar } from './sidebar';

type AppShellProps = {
    children: ReactNode;
};

export function AppShell({ children }: AppShellProps) {

    const [isSidebarExpanded, setSidebarExpanded] = useState(false);
    
    return (
        <div className="flex min-h-screen">
            <Sidebar isExpanded={isSidebarExpanded} />

            <div className="flex min-w-0 flex-1 flex-col">
                <Header
                    isSidebarExpanded={isSidebarExpanded}
                    onToggleSidebar={() => setSidebarExpanded((prev) => !prev)}
                />

                <main className="flex-1 p-6">
                    {children}
                </main>
            </div>
        </div>
    );
}