import { ListBox, SearchField, Select } from "@heroui/react";

export function PortfolioToolbar() {
    return (
        // sm applies to vw of 640px and above => flex-row applies to desktop, flex-col on mobile
        <div className="flex flex-col sm:flex-row sm:items-center gap-4">
            {/* sm:flex-1 takes the remaining space, w-full means each item takes all width when stacked */}
            <SearchField className="w-full min-w-0 sm:flex-1">
                <SearchField.Group>
                    <SearchField.SearchIcon />
                    <SearchField.Input className="" placeholder="Search portfolios..." />
                    <SearchField.ClearButton />
                </SearchField.Group>
            </SearchField>

            {/* stable width of w-64 and disables shrinking when on desktop */}
            <Select className="w-full sm:w-64 sm:shrink-0">
                <Select.Trigger>
                    <Select.Value />
                    <Select.Indicator />
                </Select.Trigger>
                <Select.Popover>
                    <ListBox>
                        <ListBox.Item id="newest" textValue="Newest">
                            Newest
                        </ListBox.Item>
                        <ListBox.Item id="oldest" textValue="Oldest">
                            Oldest
                        </ListBox.Item>
                        <ListBox.Item id="a-z" textValue="A-Z">
                            A-Z
                        </ListBox.Item>
                        <ListBox.Item id="z-a" textValue="Z-A">
                            Z-A
                        </ListBox.Item>
                    </ListBox>
                </Select.Popover>
            </Select>
        </div>
    )
}