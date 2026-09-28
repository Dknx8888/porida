import { gql } from "@apollo/client";

export const CREATE_PORTFOLIO_MUTATION = gql`
  mutation CreatePortfolio($input: CreatePortfolioInput!) {
    createPortfolio(input: $input) {
      id
      name
      createdAt
      updatedAt
    }
  }
`;