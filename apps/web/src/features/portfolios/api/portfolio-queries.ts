import { api } from "@/lib/api/client";
import { useQuery } from '@tanstack/react-query'

// List
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

        // This comment is to compare with use-portfolio
        // No () so this is passing the function without running it
        // TanStack calls it when needed then receives the promise
        queryFn: getPortfolios
    })
}

// Single one
async function getPortfolio(id: string) {
    const result = await api.GET("/api/portfolios/{id}", {
        params: {
            path: {id}
        }
    })

    if (result.response.status === 404) { return null; }

    if (!result.response.ok || !result.data) {
        throw new Error("Cannot get portfolios.")
    }

    return result.data;
}

export function usePortfolio(id: string) {
    return useQuery({
        queryKey: ['portfolios', id],

        // This comment is to compare with use-portfolios
        // If getPortfolio(id) is not wrapped by an arrow function, JS calls it immediately and the promise is stored in queryFn. TanStack wants to call a function, not that.
        queryFn: () => getPortfolio(id)
    })
}