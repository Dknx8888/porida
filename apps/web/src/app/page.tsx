import { TitleBar } from "@/components/layout/titlebar"
import { PortfolioList } from "@/features/portfolios/portfolio-list"
import { CreatePortfolioForm } from "@/features/portfolios/create-portfolio-form"

export default function Home() {
    return (
        <main className="flex flex-col gap-6">
            <TitleBar title="Your Portfolios"/>
            <PortfolioList />
            {/*<CreatePortfolioForm />*/}
        </main>
    )
}
