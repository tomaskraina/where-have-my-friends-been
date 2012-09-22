
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
    if (!placeInfo) {
        NSLog(@"Error: Can't create Location object without any info");
        return nil;
    }
    
    Location *location;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
    request.predicate = [NSPredicate predicateWithFormat:@"id = %@", placeInfo.id];
    request.sortDescriptors = nil;
    
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || matches.count > 1) {
        // handle error
        NSLog(@"Error: matches = %@", matches);
    }
    else if (matches.count == 0) {
        // create new object
        location = [NSEntityDescription insertNewObjectForEntityForName:@"Location" inManagedObjectContext:context];
        location.id = placeInfo.id;
        location.name = placeInfo.name;
        if ([placeInfo.location isKindOfClass:[FBGraphObject class]]) {
            id<FBGraphLocation> locationInfo = placeInfo.location;
            location.city = locationInfo.city;
            location.country = locationInfo.country;
            if ([locationInfo.longitude doubleValue] == 0) {
                NSLog(@"Error: invalid latitude or longitude: %@", locationInfo);
            }
            location.latitude = locationInfo.latitude;
            location.longitude = locationInfo.longitude;
        }
        else {
            NSLog(@"Error: invalid location: '%@'", placeInfo.location);
            [context deleteObject:location];
            return nil;
        }
    }
    else {
        // return existing
        location = [matches lastObject];
    }
    
    return location;
}


@end
