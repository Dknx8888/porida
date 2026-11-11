import { TitleBar } from "@/components/layout/titlebar"
import { PortfolioList } from "@/features/portfolios/portfolio-list"
import { CreatePortfolioForm } from "@/features/portfolios/create-portfolio-form"
import { PortfolioToolbar } from "@/features/portfolios/portfolio-toolbar"
import { Button } from "@heroui/react"
import { Plus } from "@gravity-ui/icons"
import { CreatePortfolioDialog } from "@/features/portfolios/create-portfolio-dialog"

export default function Home() {
    return (
        <main className="flex flex-col gap-6">
            <TitleBar
                title="Your Portfolios"
                action={<CreatePortfolioDialog />}
            />
            <PortfolioToolbar />
            <PortfolioList />
        </main>
    )
}
