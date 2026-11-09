import { Disclosure, Heading } from "@heroui/react"
import { usePortfolios } from "./api/portfolio-queries"
import { PortfolioSidebarItem } from "./portfolio-sidebar-item"
import { useEffect, useState } from "react"
import { usePathname } from "next/navigation"

export function PortfolioSidebar() {

    const { data, isPending, error } = usePortfolios()
    
    const hasPortfolios =
        !isPending &&
        !error &&
        data !== undefined &&
        data.length > 0;

    const [pinnedIds, setPinnedIds] = useState<string[]>([])
    const [pinsLoaded, setPinsLoaded] = useState(false);

    function togglePin(id: string) {
        setPinnedIds((previousIds) => {
            if (previousIds.includes(id)) {
                return previousIds.filter(pinnedId => pinnedId !== id)
            } else {
                return [...previousIds, id]
            }
        })
    }

    const pinnedPortfolios = (data ?? []).filter(p => pinnedIds.includes(p.id))
    const unpinnedPortfolios = (data ?? []).filter(p => !pinnedIds.includes(p.id))

    const pathName = usePathname()

    useEffect(() => {
        const timer = window.setTimeout(() => {
            try {
                const savedValue = window.localStorage.getItem(
                    "porida:pinned-portfolio-ids"
                );
    
                if (savedValue !== null) {
                    const parsed: unknown = JSON.parse(savedValue);
    
                    if (
                        Array.isArray(parsed) &&
                        parsed.every(id => typeof id === "string")
                    ) {
                        setPinnedIds(parsed);
                    }
                }
            } catch {
                // Keep the initial empty list if reading or parsing fails.
            } finally {
                setPinsLoaded(true);
            }
        }, 0);
    
        return () => window.clearTimeout(timer);
    }, []);
    
    useEffect(() => {
        if (!pinsLoaded) return;
    
        try {
            window.localStorage.setItem(
                "porida:pinned-portfolio-ids",
                JSON.stringify(pinnedIds)
            );
        } catch (error) {
            console.warn("Could not save pinned portfolios.", error);
        }
    }, [pinnedIds, pinsLoaded]);
    
    return (
        <nav
            aria-label="Portfolios"
            className="flex flex-col border-l border-separator shrink-0 px-3 h-full w-full"
        >
            <Heading className="flex h-18 shrink-0 items-center justify-center text-xl font-semibold tracking-tight whitespace-nowrap text-surface-foreground">
                PoRiDa
            </Heading>
            
            <Disclosure
                defaultExpanded
                className="border-b border-separator-secondary">
        
                <Disclosure.Heading>
                    <Disclosure.Trigger className="text-muted w-full flex items-center justify-between text-sm py-2">
                        Pinned
                        <Disclosure.Indicator />
                    </Disclosure.Trigger>
                </Disclosure.Heading>
        
                {hasPortfolios &&
                    <Disclosure.Content>
                        <div className="py-2">
                            {pinnedPortfolios.map((portfolio) => (
                                <PortfolioSidebarItem
                                    key={portfolio.id}
                                    id={portfolio.id}
                                    name={portfolio.name}
                                    isPinned={pinnedIds.includes(portfolio.id)}
                                    onTogglePin={() => togglePin(portfolio.id)}
                                    isSelected={pathName === `/portfolios/${portfolio.id}`}
                                />
                            ))}
                        </div>
                    </Disclosure.Content>}
            </Disclosure>
        
            {hasPortfolios &&
                <div className="py-2">
                    {unpinnedPortfolios.map((portfolio) => (
                        <PortfolioSidebarItem
                            key={portfolio.id}
                            id={portfolio.id}
                            name={portfolio.name}
                            isPinned={pinnedIds.includes(portfolio.id)}
                            onTogglePin={() => togglePin(portfolio.id)}
                            isSelected={pathName === `/portfolios/${portfolio.id}`}
                        />
                    ))}
                </div>}
        
        </nav>
    )
}

