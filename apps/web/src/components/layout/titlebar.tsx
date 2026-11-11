import { Typography } from "@heroui/react"
import { ReactNode } from "react"

type TitleBarProps = {
    title: string
    action?: ReactNode
}

export function TitleBar({ title, action }: TitleBarProps) {
    return (
        <div className="flex items-center justify-between gap-4">
            <Typography type="h1">{title}</Typography>
                { action }
        </div>
    )
}