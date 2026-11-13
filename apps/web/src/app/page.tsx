"use client"

import { TitleBar } from "@/components/layout/titlebar"
import { PortfolioList } from "@/features/portfolios/portfolio-list"
import { CreatePortfolioForm } from "@/features/portfolios/create-portfolio-form"
import { PortfolioToolbar } from "@/features/portfolios/portfolio-toolbar"
import { Button } from "@heroui/react"
import { Plus } from "@gravity-ui/icons"
import { CreatePortfolioDialog } from "@/features/portfolios/create-portfolio-dialog"
import { useState, useEffect } from "react"
import type { PortfolioSort } from "@/features/portfolios/portfolio-types"

const PORTFOLIO_SORT_KEY = "porida:portfolio-sort";

export default function Home() {

    function handleSortChange(nextSort: PortfolioSort) {
        setSortOrder(nextSort);
    
        try {
            window.localStorage.setItem(PORTFOLIO_SORT_KEY, nextSort);
        } catch (error) {
            console.warn("Could not save portfolio sorting.", error);
        }
    }

    // Pass the sort option into both the toolbar and list
    const [sortOrder, setSortOrder] = useState<PortfolioSort>("newest");
    
    return (
        <main className="flex flex-col gap-6">
            <TitleBar
                title="Your Portfolios"
                action={<CreatePortfolioDialog />}
            />
            <PortfolioToolbar
                sortOrder={sortOrder}
                onSortChange={handleSortChange}
            />
            <PortfolioList sortOrder={sortOrder} />
        </main>
    )
}
