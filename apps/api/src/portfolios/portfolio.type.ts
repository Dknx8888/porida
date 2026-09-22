import { Field, ID, ObjectType, GraphQLISODateTime } from '@nestjs/graphql'

// We could put @Entity and @ObjectType on the same class, then use:
// @Column and @Field together for stored, exposed properties.
// Only @Field for calculated API properties.
// But keeping two classes separate like this separates responsibilities.
@ObjectType('Portfolio')
export class PortfolioType {

    @Field(() => ID)
    id!: string;

    @Field(() => String)
    name!: string;

    @Field(() => GraphQLISODateTime)
    createdAt!: Date;

    @Field(() => GraphQLISODateTime)
    updatedAt!: Date;
}