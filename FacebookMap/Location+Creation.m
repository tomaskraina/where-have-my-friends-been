
//  Location+Creation.m
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Location+Creation.h"

@implementation Location (Creation)

// use variable substitution for LOCATION_ID
+ (id)sharedPredicateWithLocationId
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [NSPredicate predicateWithFormat:@"id = $LOCATION_ID"];
    });
    return sharedInstance;
}

+ (Location *)locationWithFacebookInfo:(NSDictionary<FBGraphPlace> *)placeInfo
                inManagedObjectContext:(NSManagedObjectContext *)context
{
    if (!placeInfo) {
        NSLog(@"Error: Can't create Location object without any info");
        return nil;
    }
    
    Location *location;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
    NSDictionary *variables = [NSDictionary dictionaryWithObject:[placeInfo objectForKey:@"id"] forKey:@"LOCATION_ID"];
    request.predicate = [[self sharedPredicateWithLocationId] predicateWithSubstitutionVariables:variables];
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
