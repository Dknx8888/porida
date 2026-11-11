"use client";

import { useCreatePortfolio } from "./api/portfolio-mutations";
import { Button, Form, Input, Label, TextField } from "@heroui/react";
import { useState } from "react";

type CreatePortfolioFormProps = {
    onCreated: () => void
}

export function CreatePortfolioForm({ onCreated }: CreatePortfolioFormProps) {
    const createPortfolioMutation = useCreatePortfolio();
    
    const [name, setName] = useState("");
    
    return (
        <Form
            className="flex flex-col gap-6 items-center"
            onSubmit={(e) => {
                e.preventDefault(); // Stops the browser's normal form nav
                const trimmedName = name.trim();
                if (!trimmedName || createPortfolioMutation.isPending) return;
                createPortfolioMutation.mutate(trimmedName, {
                    onSuccess: onCreated,
                });
            }}
        >
            <div className="w-full">
                <TextField
                    isRequired
                    name="name"
                    value={name}
                    onChange={(newName) => setName(newName)}
                >
                    <Label>Name</Label>
                    <Input placeholder="Long Term Investments" />
                </TextField>
            </div>
            <Button
                type="submit"
                isDisabled={!name.trim() || createPortfolioMutation.isPending}
            >
                Create Portfolio</Button>
        </Form>
    );
}