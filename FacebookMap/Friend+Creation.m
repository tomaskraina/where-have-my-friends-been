//
//  Friend+Creation.m
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Friend+Creation.h"

@implementation Friend (Facebook)

+ (Friend *)friendWithFacebookInfo:(NSDictionary<FBGraphUser> *)userInfo
            inManagedObjectContext:(NSManagedObjectContext *)context
{
    Friend *friend;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    request.predicate = [NSPredicate predicateWithFormat:@"id = %@", userInfo.id];
    request.sortDescriptors = nil;
    
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || matches.count > 0) {
        // handle error
    }
    else if (matches.count == 0) {
        // create new object
        friend = [NSEntityDescription insertNewObjectForEntityForName:@"Friend" inManagedObjectContext:context];
        friend.id = userInfo.id;
        friend.name = userInfo.name;
        friend.username = userInfo.username;
    }
    else {
        // return existing
        friend = [matches lastObject];
    }

    return friend;
}

@end
