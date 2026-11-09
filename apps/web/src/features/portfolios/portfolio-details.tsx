"use client";

import { usePortfolio } from "./api/portfolio-queries";
import { TitleBar } from "@/components/layout/titlebar";

// React supplies { id: "aaa" } when <PortfolioDetails id="aaa" />
// So PortfolioDetails(id: string) does not work
export function PortfolioDetails({ id }: { id: string }) {
    const { data, isPending, error } = usePortfolio(id)

    if (isPending) {
        return <p>Loading portfolio...</p>
    }

    if (error) {
        return <p>Could not load portfolio.</p>
    }

    if (data === null) {
        return <p>Portfolio not found.</p>
    }

    return <TitleBar title={data.name} />;
}