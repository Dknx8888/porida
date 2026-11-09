import { Plus } from "@gravity-ui/icons"
import { Button, Typography } from "@heroui/react"


type TitleBarProps = {
    title: string,
    
}

export function TitleBar({ title }: TitleBarProps) {
    return (
        <div className="flex items-center justify-between gap-4">
            <Typography type="h1">{title}</Typography>
            <Button>
                <Plus /> Add
            </Button>
        </div>
    )
}