"use client";

import { LayoutSideContentLeft, Bell, Gear, ArrowRightFromSquare } from '@gravity-ui/icons';
import { Button, Dropdown, Avatar, Label, Typography, Switch } from '@heroui/react';
import NextLink from 'next/link';
import { useEffect, useState } from 'react';

const placeholderAvatar = {
    src: '/images/shrek-realtoons.jpg',
    alt: 'Shrek Doe'
}

type HeaderProps = {
    isSidebarExpanded: boolean,
    onToggleSidebar: () => void,
}

function getGreeting(hour: number): string {
    if (hour < 5) return "night";
    if (hour < 12) return "morning";
    if (hour < 19) return "afternoon";
    if (hour < 22) return "evening";

    return "night";
}

export function Header({ isSidebarExpanded, onToggleSidebar }: HeaderProps) {
    
    const [greeting, setGreeting] = useState("day");

    // useEffect here to stop rerendering timer setup every normal rerender
    useEffect(() => {
        function updateGreeting() {
            setGreeting(getGreeting(new Date().getHours()));
        }

        // Starts timer
        const initialUpdate = window.setTimeout(updateGreeting, 0);
        // Checks time every minute
        const interval = window.setInterval(updateGreeting, 60_000);
        // initialUpdate and interval are timer IDs returned from function calls
        
        return () => {
            // If Header unmounts, this needs to be cleaned up else another interval caller runs. (kinda like freeing memory in C)
            window.clearTimeout(initialUpdate);
            window.clearInterval(interval);
        };
    }, [])
    
    return (
        <header className="flex min-h-18 w-full shrink-0 items-center justify-between gap-4 px-4 py-3 sm:px-8">
            <div className="flex min-w-0 items-center gap-3">
                <Button
                    isIconOnly variant='ghost'
                    onClick={onToggleSidebar}
                    aria-label={isSidebarExpanded ? "Collapse sidebar" : "Expand sidebar"}
                    aria-expanded={isSidebarExpanded}
                    aria-controls="app-sidebar"
                >
	                <LayoutSideContentLeft aria-hidden="true" />
                </Button>
                <NextLink href="/">
	                <Typography weight='bold'>
	                    Good {greeting}, name!
	                </Typography>
                </NextLink>
            </div>

            <div className="flex shrink-0 items-center gap-3">
                
                <Dropdown>
                    <Button isIconOnly variant='ghost' aria-label='Notifications Toggle'>
                        <Bell />
                    </Button>
                    <Dropdown.Popover>
                        <p>placeholder</p>
                    </Dropdown.Popover>
                </Dropdown>

                <Dropdown>
                    <Button isIconOnly variant='ghost' aria-label='Profile Options'>
                        <Avatar>
                            <Avatar.Image {...placeholderAvatar} />
                            <Avatar.Fallback delayMs={600}>SD</Avatar.Fallback>
                        </Avatar>
                    </Button>
                    <Dropdown.Popover>
                        <div className='px-3 pt-3 pb-1'>
                            <div className='flex items-center gap-2'>
                                <Avatar size="sm">
                                    <Avatar.Image {...placeholderAvatar} />
                                    <Avatar.Fallback delayMs={600}>SD</Avatar.Fallback>
                                </Avatar>
                                <div className='flex flex-col gap-0'>
                                	<p className="text-sm leading-5 font-medium">Shrek Doe</p>
                                    <p className="text-xs leading-none text-muted">shrek@example.com</p>
                                </div>
                            </div>
                        </div>
                        <Dropdown.Menu onAction={(key) => console.log(`Selected: ${key}`)}>
                            <Dropdown.Item id="settings" textValue='Settings'>
	                            <div className="flex w-full items-center justify-between gap-2">
	                              <Label>Settings</Label>
	                              <Gear className="size-3.5 text-muted" />
	                            </div>
                            </Dropdown.Item>
                            <Dropdown.Item id="logout" textValue="Logout" variant="danger">
                              	<div className="flex w-full items-center justify-between gap-2">
                                	<Label>Log Out</Label>
                                 	<ArrowRightFromSquare className="size-3.5 text-danger" />
                               	</div>
                            </Dropdown.Item>
                        </Dropdown.Menu>
                    </Dropdown.Popover>
                </Dropdown>
                
            </div>
            
        </header>
    )
}