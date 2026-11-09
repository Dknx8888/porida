import { api } from "@/lib/api/client";
import { useMutation } from '@tanstack/react-query'

async function createPortfolio(newName: string) {
    const result = await api.POST("/api/portfolios", {
        body: {
            name: newName
        }
    });

    if (!result.response.ok || !result.data) {
        throw new Error("Cannot create a portfolio.")
    }
    
    return result.data;
}

export function useCreatePortfolio() {
    return useMutation({
        mutationFn: createPortfolio,
    });
}