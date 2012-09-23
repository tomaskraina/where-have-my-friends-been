//
//  Friend+Creation.m
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Friend+Creation.h"

@implementation Friend (Facebook)

// use variable substitution for FRIEND_ID
+ (id)sharedPredicateWithFriendId
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [NSPredicate predicateWithFormat:@"id = $FRIEND_ID"];
    });
    return sharedInstance;
}

+ (Friend *)friendWithFacebookInfo:(NSDictionary<FBGraphUser> *)userInfo
            inManagedObjectContext:(NSManagedObjectContext *)context
{
    Friend *friend;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    NSDictionary *variables = [NSDictionary dictionaryWithObject:[userInfo objectForKey:@"id"] forKey:@"FRIEND_ID"];
    request.predicate = [[self sharedPredicateWithFriendId] predicateWithSubstitutionVariables:variables];
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
