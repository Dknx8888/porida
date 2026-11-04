import { Disclosure, Heading } from "@heroui/react"
import { usePortfolios } from "./use-portfolios"
import { PortfolioSidebarItem } from "./portfolio-sidebar-item"

export function PortfolioSidebar() {

    const { data, isPending, error } = usePortfolios()
    
    const hasPortfolios =
        !isPending &&
        !error &&
        data !== undefined &&
        data.length > 0;
    
    return (
        // width is 20rem expanded sidebar − 4.5rem rail − 1px outer border
        <nav aria-label="Portfolios" className="flex flex-col border-l border-separator w-61.75 shrink-0 px-3">
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
                        <p>Pinned portf</p>
                    </div>
                </Disclosure.Content>}
            
                
            </Disclosure>
        
            {hasPortfolios &&
                <div className="py-2">
                {data.map((portfolio) => (
                    <PortfolioSidebarItem
                        key={portfolio.id}
                        name={portfolio.name}
                    />
                ))}
            </div>}
            
        </nav>
    )
}

