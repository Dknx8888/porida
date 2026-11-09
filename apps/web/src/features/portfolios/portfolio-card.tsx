import { Button, Card, Typography, Dropdown, Label } from '@heroui/react';
import { Ellipsis } from '@gravity-ui/icons'
import NextLink from "next/link"

type PortfolioCardProps = {
    id: string;
    name: string;
};

export function PortfolioCard({ id, name }: PortfolioCardProps) {
    return (
        <Card className='isolate'>
            <NextLink
                href={`/portfolios/${id}`}
                aria-label={`Open ${name}`}
                // rounded-[inherit] etc. for the keyboard tab outline
                className="absolute inset-0 z-10
                rounded-[inherit] outline-none 
                focus-visible:ring-2 focus-visible:ring-accent"
            />
            <Card.Header className='flex-row justify-between items-center'>
                
                <Card.Title className='text-xl font-semibold'>{name}</Card.Title>
                
                <Dropdown>
                    <Button isIconOnly variant='ghost' aria-label='Portfolio Options' className="z-20">
                        <Ellipsis />
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
                
            </Card.Header>

            <Card.Content>
                <div>
	                <Typography.Paragraph className='text-3xl' weight='semibold'>
	                    $250,142
	                </Typography.Paragraph>
	
	                <div className='flex text-xs pt-2'>
	                    <p className='text-green-600'>↑ 2.5%</p>
	                    <p className='text-muted'> · Past 30 days</p>
	                </div>
                </div>

                <div>
                    
                </div>

            </Card.Content>
        </Card>
    );
}