import { gql } from "@apollo/client";

export const PORTFOLIOS_QUERY = gql`
    query GetPortfolios {
        portfolios {
            id
            name
            createdAt
            updatedAt
        }
    }
`;