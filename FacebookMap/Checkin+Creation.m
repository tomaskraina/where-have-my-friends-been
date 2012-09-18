//
//  Checkin+Creation.m
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Checkin+Creation.h"
#import "Location+Creation.h"

@implementation Checkin (Creation)

+ (Checkin *)checkinWithFacebookInfo:(NSDictionary *)checkinInfo
                             forUser:(Friend *)user
              inManagedObjectContext:(NSManagedObjectContext *)context
{
    Checkin *checkin;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Checkin"];
    request.predicate = [NSPredicate predicateWithFormat:@"id = %@", [checkinInfo objectForKey:@"id"]];
    request.sortDescriptors = nil;
    
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    if (!matches || matches.count > 1) {
        // handle error
    }
    else if (matches.count == 0) {
        // create
        checkin = [NSEntityDescription insertNewObjectForEntityForName:@"Checkin" inManagedObjectContext:context];
        checkin.id = [checkinInfo objectForKey:@"id"];
        checkin.type = [checkinInfo objectForKey:@"type"];
        checkin.from_id = [[checkinInfo objectForKey:@"from"] objectForKey:@"id"];
        checkin.from_name = [[checkinInfo objectForKey:@"from"] objectForKey:@"name"];
        // TODO: convert string to NSDate
//        checkin.created_time = [checkinInfo objectForKey:@"created_time"];
        checkin.location = [Location locationWithFacebookInfo:[checkinInfo objectForKey:@"place"] inManagedObjectContext:context];
        [checkin addWhoHasBeenThereObject:user];
    }
    else {
        checkin = [matches lastObject];
        [checkin addWhoHasBeenThereObject:user];
    }
    
    return checkin;
}

@end
