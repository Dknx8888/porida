"use client";

import type { ReactNode } from "react";
import { HttpLink } from "@apollo/client";
import {
  ApolloClient,
  ApolloNextAppProvider,
  InMemoryCache,
} from "@apollo/client-integration-nextjs";

function makeClient() {
    const graphqlUrl = process.env.NEXT_PUBLIC_GRAPHQL_URL;

    if (!graphqlUrl) {
        throw new Error("NEXT_PUBLIC_GRAPHQL_URL is not configured");
    }
    
    return new ApolloClient({
        link: new HttpLink({
            uri: graphqlUrl
        }),
        cache: new InMemoryCache()
    });
}

export function ApolloProvider({ children }: { children: ReactNode }) {
    return (
        <ApolloNextAppProvider makeClient={makeClient}>
            {children}
        </ApolloNextAppProvider>
    );
}