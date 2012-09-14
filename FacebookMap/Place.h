//
//  Place.h
//  FacebookMap
//
//  Created by Tom Kraina on 14.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class LocationObject;

@interface Place : NSManagedObject

@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * city;
@property (nonatomic, retain) NSString * country;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSSet *locations;
@end

@interface Place (CoreDataGeneratedAccessors)

- (void)addLocationsObject:(LocationObject *)value;
- (void)removeLocationsObject:(LocationObject *)value;
- (void)addLocations:(NSSet *)values;
- (void)removeLocations:(NSSet *)values;
@end
