"use client";

import { api } from "@/lib/api/client";
import { useMutation } from "@tanstack/react-query";
import { Button, Card, Form, Input, Label, TextField } from "@heroui/react";

async function createPortfolio(newName: string) {
    const result = await api.POST("/api/portfolios", {
        body: {
            name: newName
        }
    });

    if (!result.response.ok || !result.data) {
        throw new Error("Cannot create a portfolio.")
    }
    
    return result.data;
}

export function CreatePortfolioForm() {
    const createPortfolioMutation = useMutation({
        mutationFn: createPortfolio
    })
    
    return (
        <Card>
	        <Form>
	            <Button type="submit">Create Portfolio</Button>
	        </Form>
        </Card>

    );
}