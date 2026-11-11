import { api } from "@/lib/api/client";
import { useMutation, useQueryClient } from '@tanstack/react-query'

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
    // This retrieves the existing cache used by the homepage and sidebar
    const queryClient = useQueryClient();
    return useMutation({
        mutationFn: createPortfolio,
        // Invalidation marks that cached list as outdated and refetches it while it’s being displayed
        // Both components then receive the updated list
        onSuccess: async () => {
            await queryClient.invalidateQueries({
                queryKey: ["portfolios"],
                exact: true
            })
        }
    });
}