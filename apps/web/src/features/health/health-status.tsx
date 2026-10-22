"use client";

import { api } from "@/lib/api/client";
import { useQuery } from "@tanstack/react-query";

async function getHealth() {
    const result = await api.GET("/api/health");

    if (!result.response.ok || !result.data) {
        throw new Error("Cannot get health status.")
    }
    
    return result.data;
}

export function HealthStatus() {
    const { data, isPending, error } = useQuery({
        queryKey: ['health'],
        queryFn: getHealth,
    })
    
    if (isPending) {
        return <p>Checking API...</p>;
    } 

    if (error) {
      return <p>API connection failed: {error.message}</p>;
    }

// `data` state means the operation completed successfully    
  return <p>API status: {data?.status ?? "unknown"}</p>;
}