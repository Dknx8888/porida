import { Moon, Sun } from "@gravity-ui/icons"
import {  Link, Switch } from "@heroui/react"
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";
import Image from "next/image";
import { PortfolioSidebar } from "@/features/portfolios/portfolio-sidebar";

type SidebarProps = {
    isExpanded: boolean
}

export function Sidebar({ isExpanded }: SidebarProps) {

    const { resolvedTheme, setTheme } = useTheme();
    const [mounted, setMounted] = useState(false);

    // The browser schedules the mount to run once, after the current JS finishes
    useEffect(() => {
        const timer = window.setTimeout(() => {
            setMounted(true);
        }, 0);

        // If the sidebar is removed while callback is still pending, React calls this cleanup function and cancels it. Has no effect otherwise.
        return () => window.clearTimeout(timer);
    }, []);
    
    return (
        <aside
            className={`flex min-h-screen overflow-hidden shrink-0 bg-surface text-surface-foreground border-r border-separator
                transition-[width] duration-200 ${isExpanded ? "w-80" : "w-18"}`}>
                
            <div className="w-18 shrink-0 flex flex-col bg-surface-secondary">

                <Link href="/" aria-label="Go to homepage" className="flex h-18 w-18 shrink-0 items-center justify-center">
                    <Image
                        src="/logoipsum-441.svg"
                        alt="PoRiDa"
                        width={40}
                        height={40}
                        className="object-contain"
                    />
                </Link>

                <div className="flex-1">
                    
                </div>

                {/*Theme Button*/}
                <div className="p-4 flex items-center justify-center">
                    {mounted && (
                        <Switch
                            isSelected={resolvedTheme === "light"}
                            aria-label="Theme switcher"
                            size="lg"
                            onChange={(selected) => {
                                setTheme(selected ? "light" : "dark");
                            }}
                        >
                            {({ isSelected }) => (
                                <Switch.Content>
                                    <Switch.Control>
                                        <Switch.Thumb>
                                            <Switch.Icon>
                                                {isSelected ? 
                                                    <Sun className="size-3 opacity-100" /> :
                                                    <Moon className="size-3 opacity-70" />
                                                }
                                            </Switch.Icon>
                                        </Switch.Thumb>
                                    </Switch.Control>
                                </Switch.Content>
                            )}
                        </Switch>
                    )}
                </div>

            </div>
            
        <PortfolioSidebar />
        </aside>
    );
}