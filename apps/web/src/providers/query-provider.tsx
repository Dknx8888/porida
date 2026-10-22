"use client";

import type { ReactNode } from "react";
import {
    QueryClient,
    QueryClientProvider,
} from "@tanstack/react-query";

let browserClient: QueryClient | undefined;

function getQueryClient() {
    if (typeof window === "undefined") {
    return new QueryClient();
    }

    if (!browserClient) {
    browserClient = new QueryClient();
    }

    return browserClient;
}

export function QueryProvider({
    children,
}: {
    children: ReactNode;
}) {
    return (
    <QueryClientProvider client={getQueryClient()}>
        {children}
    </QueryClientProvider>
    );
}
