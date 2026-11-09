"use client";

import { useCreatePortfolio } from "./api/portfolio-mutations";
import { Button, Card, Form, Input, Label, TextField } from "@heroui/react";



export function CreatePortfolioForm() {
    const createPortfolioMutation = useCreatePortfolio();

    // createPortfolioMutation.mutate(name);
    
    return (
        <Card>
	        <Form>
	            <Button type="submit">Create Portfolio</Button>
	        </Form>
        </Card>

    );
}