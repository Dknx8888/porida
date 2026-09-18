import { Query, Resolver } from '@nestjs/graphql';

// Gets
// 
// type Query {
//   health: String!
// }
@Resolver()
export class HealthResolver {
    @Query(() => String)
    health(): string {
        return 'ok';
    }
}