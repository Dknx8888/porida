import type { components } from "@/lib/api/schema";

export type PortfolioDto = components["schemas"]["PortfolioDto"];

export type PortfolioSort =
    | "newest"
    | "oldest"
    | "a-z"
    | "z-a";