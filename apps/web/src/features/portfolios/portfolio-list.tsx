"use client";

import { PortfolioCard } from "./portfolio-card";
import { usePortfolios } from "./api/portfolio-queries";
import type { PortfolioSort, PortfolioDto } from "./portfolio-types";

type PortfolioListProps = {
    sortOrder: PortfolioSort
}

// Neg => put a first, pos => put b first
function comparePortfolios(
    a: PortfolioDto,
    b: PortfolioDto,
    sortOrder: PortfolioSort
): number
{
    const aTime = Date.parse(a.createdAt);
    const bTime = Date.parse(b.createdAt);
    
    switch (sortOrder) {
        case "a-z":
            return a.name.localeCompare(b.name);

        case "z-a":
            return b.name.localeCompare(a.name);

        case "oldest":
            return aTime - bTime

        case "newest":
            return bTime - aTime

        default:
            return 0;
    }
}

export function PortfolioList({ sortOrder }: PortfolioListProps) {
    const { data, isPending, error } = usePortfolios()

    if (isPending) {
        return <p>Loading portfolios...</p>
    }

    if (error) {
        return <p>Could not load portfolios.</p>
    }

    if (!data) {
        return <p>Unable to fetch data. Please try again.</p>
    }

    if (data.length === 0) {
        return <p>No portfolios yet.</p>
    }

    // Neg => put a first, pos => put b first
    const sortedPortfolios = [...data].sort((a, b) => comparePortfolios(a, b, sortOrder))
    
    return (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
	        {sortedPortfolios.map((portfolio) => (
                <PortfolioCard
                    id={portfolio.id}
	                key={portfolio.id}
	                name={portfolio.name}
	            />
	        ))}
        </div>
    )
}