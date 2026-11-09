"use client";

import { useState, type ReactNode } from 'react';
import { Header } from './header';
import { Sidebar } from './sidebar';
import { PortfolioSidebar } from '@/features/portfolios/portfolio-sidebar';
import { Panel, Group, Separator } from 'react-resizable-panels';
import { usePanelRef } from 'react-resizable-panels';
import type { PanelImperativeHandle } from 'react-resizable-panels';

type AppShellProps = {
    children: ReactNode;
};

const SIDEBAR_WIDTH_KEY = "porida:sidebar-width";

function toggleSidebar(panel: PanelImperativeHandle | null) {
    if (!panel) { return }
    if (panel.isCollapsed()) {
        const savedWidth = Number(
            window.localStorage.getItem(SIDEBAR_WIDTH_KEY)
        );
        
        const width =
            savedWidth >= 200 && savedWidth <= 400
                ? savedWidth
                : 248;
        
        panel.resize(`${width}px`);
    } else {
        panel.collapse();
    }
}

export function AppShell({ children }: AppShellProps) {

    const [isSidebarExpanded, setSidebarExpanded] = useState(false);

    const portfolioPanelRef = usePanelRef();

    return (
        <div className="flex h-dvh overflow-hidden">
            <Sidebar />

            <Group orientation="horizontal" className="min-w-0 flex-1 sidebar-panels">
                <Panel
                    id="app-sidebar"
                    panelRef={portfolioPanelRef}
                    collapsible
                    collapsedSize="0px"
                    defaultSize="0px"
                    minSize="200px"
                    maxSize="400px"
                    groupResizeBehavior='preserve-pixel-size'
                    onResize={(size) => {
                        setSidebarExpanded(size.inPixels > 0);
                    
                        const panel = portfolioPanelRef.current;
                    
                        if (panel && !panel.isCollapsed() && size.inPixels >= 200) {
                            window.localStorage.setItem(
                                SIDEBAR_WIDTH_KEY,
                                String(size.inPixels)
                            );
                        }
                    }}
                >
                    <PortfolioSidebar />
                </Panel>
                
                <Separator className="w-1 bg-separator hover:bg-accent" />
                <Panel>
                    <div className="flex min-w-0 h-full flex-col">
                        <Header
                            isSidebarExpanded={isSidebarExpanded}
                            onToggleSidebar={() => toggleSidebar(portfolioPanelRef.current)}
                        />
        
                        <main className="min-h-0 flex-1 overflow-y-auto p-6">
                            {children}
                        </main>
                    </div>
                </Panel>
            </Group>
        </div>
    );
}