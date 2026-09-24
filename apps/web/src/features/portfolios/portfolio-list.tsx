"use client"

import { useQuery } from "@apollo/client/react";
import { PORTFOLIOS_QUERY } from "@/graphql/queries/portfolios";

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
        <ul>
            {data.portfolios.map((portfolio) => (
            <li key={portfolio.id}>{portfolio.name}</li>
            ))}
        </ul>
    )
}