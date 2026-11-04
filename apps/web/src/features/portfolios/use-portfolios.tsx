import { api } from "@/lib/api/client";
import { useQuery } from '@tanstack/react-query'

async function getPortfolios() {
    const result = await api.GET("/api/portfolios");

    if (!result.response.ok || !result.data) {
        throw new Error("Cannot get portfolios.")
    }
    
    return result.data;
}

export function usePortfolios() {
    return useQuery({
        queryKey: ['portfolios'],
        queryFn: getPortfolios,
    })
}