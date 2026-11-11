"use client"

import { Modal, Button } from "@heroui/react"
import { Plus } from "@gravity-ui/icons"
import { CreatePortfolioForm } from "./create-portfolio-form"

export function CreatePortfolioDialog() {
    return (
        <Modal>
            <Button><Plus /> Add</Button>
            <Modal.Backdrop>
                <Modal.Container>
                    <Modal.Dialog>
                        {({ close }) => (
                            <>
                                <Modal.CloseTrigger />
                    
                                <Modal.Header>
                                    <Modal.Heading>Create Portfolio</Modal.Heading>
                                </Modal.Header>
                    
                                <Modal.Body>
                                    <CreatePortfolioForm onCreated={close} />
                                </Modal.Body>
                            </>
                        )}
                    </Modal.Dialog>
                </Modal.Container>
            </Modal.Backdrop>
        </Modal>
    )
}