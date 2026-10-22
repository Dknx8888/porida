"use client";

import { api } from "@/lib/api/client";
import { useQuery } from '@tanstack/react-query'

import { PortfolioCard } from "./portfolio-card";

async function getPortfolios() {
    const result = await api.GET("/api/portfolios");

    if (!result.response.ok || !result.data) {
        throw new Error("Cannot get portfolios.")
    }
    
    return result.data;
}

export function PortfolioList() {
    const { data, isPending, error } = useQuery({
        queryKey: ['portfolios'],
        queryFn: getPortfolios,
    })

    if (isPending) {
        return <p>Loading portfolios...</p>
    }

    if (error) {
        return <p>Could not load portfolios.</p>
    }

    if (!data) {
        return <p>Portfolio data is unavailable.</p>
    }

    if (data.length === 0) {
        return <p>No portfolios yet.</p>
    }
    
    return (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
	        {data.map((portfolio) => (
	            <PortfolioCard
	                key={portfolio.id}
	                name={portfolio.name}
	            />
	        ))}
        </div>
    )
}