"use client";

import { useQuery } from "@apollo/client/react";
import { HEALTH_QUERY } from "@/graphql/queries/health";

type HealthQueryData = {
  health: string;
};

export function HealthStatus() {
  const { data, loading, error } = useQuery<HealthQueryData>(HEALTH_QUERY, {
    ssr: false,
  });

  if (loading) {
    return <p>Checking API...</p>;
  }

  if (error) {
    return <p>API connection failed: {error.message}</p>;
  }

// `data` state means the operation completed successfully    
  return <p>API status: {data?.health ?? "unknown"}</p>;
}