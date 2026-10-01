"use client";

import { LayoutSideContentLeft, Bell, Gear, ArrowRightFromSquare } from '@gravity-ui/icons';
import { Button, Dropdown, Avatar, Label, Typography } from '@heroui/react';
import NextLink from 'next/link';

const placeholderAvatar = {
    src: '/images/shrek-realtoons.jpg',
    alt: 'Shrek Doe'
}

export function Header() {
    return (
        <header className="flex min-h-18 w-full shrink-0 items-center justify-between gap-4 px-4 py-3 sm:px-8">
            <div className="flex min-w-0 items-center gap-3">
	            <Button isIconOnly variant='ghost' aria-label='Sidebar Toggle'>
	                <LayoutSideContentLeft />
                </Button>
                <NextLink href="/">
	                <Typography weight='bold'>
	                    Dashboard
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