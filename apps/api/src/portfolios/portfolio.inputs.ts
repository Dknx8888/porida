import { Field, InputType } from "@nestjs/graphql";
import { Transform } from 'class-transformer';
import { IsString, IsNotEmpty } from 'class-validator';

@InputType()
export class CreatePortfolioInput {
    // Exposes the field in the GraphQL input
    @Field(() => String) 

    // Transform and validate the input
    @Transform(({ value }: { value: unknown }) =>
        typeof value === 'string' ? value.trim() : value,
    )
    @IsString()
    @IsNotEmpty({ message: 'Portfolio name must not be empty.' })

    // Input
    name!: string
}