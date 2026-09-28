"use client"

import { useQuery } from "@apollo/client/react";
import { PORTFOLIOS_QUERY } from "@/graphql/queries/portfolios";

import { PortfolioCard } from "./portfolio-card";

type PortfolioListItem = {
    id: string,
    name: string,
    createdAt: string,
    updatedAt: string
}

type PortfoliosQueryData = {
    portfolios: PortfolioListItem[]
}

// “Run or observe this portfolio query through Apollo, and give this component its current result.”
export function PortfolioList() {
    const { data, loading, error } = useQuery<PortfoliosQueryData>(PORTFOLIOS_QUERY, {
        ssr: false
    })

    if (loading) {
        return <p>Loading portfolios...</p>
    }

    if (error) {
        return <p>Could not load portfolios.</p>
    }

    if (!data) {
        return <p>Portfolio data is unavailable.</p>
    }

    if (data.portfolios.length === 0) {
        return <p>No portfolios yet.</p>
    }
    
    return (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
	        {data.portfolios.map((portfolio) => (
	            <PortfolioCard
	                key={portfolio.id}
	                name={portfolio.name}
	            />
	        ))}
        </div>
    )
}