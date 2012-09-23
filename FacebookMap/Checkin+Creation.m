//
//  Checkin+Creation.m
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Checkin+Creation.h"
#import "Location+Creation.h"

#define FACEBOOK_DATETIME_FORMAT @"yyyy-MM-dd'T'HH:mm:ssZZZZ"

@implementation Checkin (Creation)


// use variable substitution for CHECKIN_ID
+ (id)sharedPredicateWithCheckinId
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [NSPredicate predicateWithFormat:@"id = $CHECKIN_ID"];
    });
    return sharedInstance;
}

+ (NSDateFormatter *)sharedFacebookDateFormatter
{
    static dispatch_once_t once;
    static NSDateFormatter *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[NSDateFormatter alloc] init];
        sharedInstance.dateFormat = FACEBOOK_DATETIME_FORMAT;
    });
    return sharedInstance;
}

+ (Checkin *)checkinWithFacebookInfo:(NSDictionary *)checkinInfo
                             forUser:(Friend *)user
              inManagedObjectContext:(NSManagedObjectContext *)context
{
    Checkin *checkin;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Checkin"];
    NSDictionary *variables = [NSDictionary dictionaryWithObject:[checkinInfo objectForKey:@"id"] forKey:@"CHECKIN_ID"];
    request.predicate = [[self sharedPredicateWithCheckinId] predicateWithSubstitutionVariables:variables];
    request.sortDescriptors = nil;
    
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    if (!matches || matches.count > 1) {
        // handle error
    }
    else if (matches.count == 0) {
        // validate
        if (![checkinInfo objectForKey:@"place"]) {
            NSLog(@"Error: Checkin has no location data.");
            NSLog(@"Error: Checkin info: %@", checkinInfo);
            return nil;
        }
        
        // create
        checkin = [NSEntityDescription insertNewObjectForEntityForName:@"Checkin" inManagedObjectContext:context];
        checkin.id = [checkinInfo objectForKey:@"id"];
        checkin.type = [checkinInfo objectForKey:@"type"];
        checkin.from_id = [[checkinInfo objectForKey:@"from"] objectForKey:@"id"];
        checkin.from_name = [[checkinInfo objectForKey:@"from"] objectForKey:@"name"];

        // Convert string to NSDate;
        checkin.created_time = [[self sharedFacebookDateFormatter] dateFromString:[checkinInfo objectForKey:@"created_time"]];
        checkin.location = [Location locationWithFacebookInfo:[checkinInfo objectForKey:@"place"] inManagedObjectContext:context];
        if (!checkin.location) {
            NSLog(@"Error creating Locations with data: %@", [checkinInfo objectForKey:@"place"]);
            [context deleteObject:checkin];
            return nil;
        }
        [checkin addWhoHasBeenThereObject:user];
    }
    else {
        checkin = [matches lastObject];
        [checkin addWhoHasBeenThereObject:user];
    }
    
    return checkin;
}

@end
