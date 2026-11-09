import { Pin, Ellipsis, PinFill } from "@gravity-ui/icons"
import { Button, Dropdown, Link, Label, cn } from "@heroui/react"
import NextLink from "next/link"

type PortfolioSidebarItemProps = {
    id: string
    name: string
    isSelected: boolean
    isPinned: boolean
    onTogglePin: () => void
}

export function PortfolioSidebarItem({ id, name, isSelected, isPinned, onTogglePin }: PortfolioSidebarItemProps) {
    return (
        <div
            className={cn(
                "group relative h-10 rounded-lg hover:bg-default",
                { "bg-default": isSelected }
            )}
        >
            <Link
                href={`/portfolios/${id}`}
                render={ props => {
                    if ("href" in props) {
                        return <NextLink {...props} />;
                    }
                
                    return <span {...props} />;
                }}
                className="absolute inset-0 flex h-full w-full
                    items-center rounded-lg px-2 pr-16
                    [@media(hover:hover)]:pr-2
                    group-hover:pr-16
                    group-has-aria-expanded:pr-16
                    group-has-data-focus-visible:pr-16
                    no-underline"
                aria-current={isSelected ? "page" : undefined}
            >
                   <span className="min-w-0 truncate">{name}</span>
            </Link>
            
            <div
                className="pointer-events-none absolute inset-y-0 gap-1 right-1 z-10 flex items-center
                    [@media(hover:hover)]:opacity-0
                    group-hover:opacity-100
                    group-has-aria-expanded:opacity-100
                    group-has-data-focus-visible:opacity-100"
            >
                <Dropdown>
                    <Button
                        isIconOnly
                        variant='ghost'
                        size='sm'
                        className="pointer-events-auto size-7"
                        aria-label='Portfolio Options'>
                        <Ellipsis className="size-3.5"/>
                    </Button>
                    <Dropdown.Popover>
                        <Dropdown.Menu onAction={(key) => console.log(`Selected: ${key}`)}>
                            <Dropdown.Item id="rename" textValue='Rename'>
                                <Label>Rename</Label>
                            </Dropdown.Item>
                            <Dropdown.Item id="delete" textValue='Delete' variant='danger'>
                                <Label>Delete</Label>
                            </Dropdown.Item>
                        </Dropdown.Menu>
                    </Dropdown.Popover>
                </Dropdown>
                <Button
                    isIconOnly
                    variant="ghost"
                    size="sm"
                    className="pointer-events-auto size-7"
                    aria-label={isPinned ? "Unpin portfolio" : "Pin portfolio"}
                    onPress={onTogglePin}
                    aria-pressed={isPinned}
                >
                    {isPinned ? <PinFill className="size-3.5"/>: <Pin className="size-3.5" />}
                </Button>
            </div>
            
        </div>
    )
}