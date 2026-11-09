"use client";

import { PortfolioCard } from "./portfolio-card";
import { usePortfolios } from "./api/portfolio-queries";

export function PortfolioList() {
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
    
    return (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
	        {data.map((portfolio) => (
                <PortfolioCard
                    id={portfolio.id}
	                key={portfolio.id}
	                name={portfolio.name}
	            />
	        ))}
        </div>
    )
}