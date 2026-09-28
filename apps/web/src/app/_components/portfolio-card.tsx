import { Button, Card, Typography, Dropdown, DropdownPopover, DropdownItem, Label } from '@heroui/react';
import { Ellipsis } from '@gravity-ui/icons'

type PortfolioCardProps = {
    name: string;
};

export function PortfolioCard({ name }: PortfolioCardProps) {
    return (
        <Card>
            <Card.Header className='flex-row justify-between items-center'>
                <Card.Title className='text-xl font-semibold'>{name}</Card.Title>
                <Dropdown>
                    <Button isIconOnly variant='ghost' aria-label='Portfolio Options'>
                        <Ellipsis className='outline-none'/>
                    </Button>
                    <DropdownPopover>
                        <Dropdown.Menu onAction={(key) => console.log(`Selected: ${key}`)}>
                            <DropdownItem id="rename" textValue='Rename'>
                                <Label>Rename</Label>
                            </DropdownItem>
                            <DropdownItem id="delete" textValue='Delete' variant='danger'>
                                <Label>Delete</Label>
                            </DropdownItem>
                        </Dropdown.Menu>
                    </DropdownPopover>
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