import { PortfolioDetails } from "@/features/portfolios/portfolio-details";

type PortfolioPageProps = {
    params: Promise<{ id: string }>;
};

export default async function PortfolioPage({
    params,
}: PortfolioPageProps) {
    const { id } = await params;

    return <PortfolioDetails id={id} />;
}