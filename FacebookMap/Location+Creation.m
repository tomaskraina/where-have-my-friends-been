//
//  Location+Creation.m
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Location+Creation.h"

@implementation Location (Creation)

+ (Location *)locationWithFacebookInfo:(NSDictionary<FBGraphPlace> *)placeInfo
                inManagedObjectContext:(NSManagedObjectContext *)context
{
    Location *location;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
    request.predicate = [NSPredicate predicateWithFormat:@"id = %@", placeInfo.id];
    request.sortDescriptors = nil;
    
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || matches.count > 0) {
        // handle error
    }
    else if (matches.count == 0) {
        // create new object
        location = [NSEntityDescription insertNewObjectForEntityForName:@"Location" inManagedObjectContext:context];
        location.id = placeInfo.id;
        location.name = placeInfo.name;
        if ([placeInfo.location conformsToProtocol:@protocol(FBGraphLocation)]) {
            location.city = placeInfo.location.city;
            location.country = placeInfo.location.country;
            location.latitude = [NSNumber numberWithDouble:[placeInfo.location.latitude doubleValue]];
            location.longitude = [NSNumber numberWithDouble:[placeInfo.location.longitude doubleValue]];
        }
        else {
            NSLog(@"Error: location is a member of ", [[placeInfo.location class] description]);
        }
    }
    else {
        // return existing
        location = [matches lastObject];
    }
    
    return location;
}


@end
