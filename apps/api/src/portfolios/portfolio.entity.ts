import { Entity, Column, PrimaryGeneratedColumn } from 'typeorm'

// Table schema.table - public.portfolio
@Entity({name: 'portfolio', schema: 'public'}) 
export class Portfolio {

    @PrimaryGeneratedColumn('uuid')
    id!: string;

    @Column({
        type: 'text'
    })
    name!: string;

    @Column({
        name: 'created_at',  // Needed to map the name also
        type: 'timestamptz',
        default: () => 'CURRENT_TIMESTAMP'
    })
    createdAt!: Date;

    @Column({
        name: 'updated_at',
        type: 'timestamptz',
        default: () => 'CURRENT_TIMESTAMP'
    })
    updatedAt!: Date;
}