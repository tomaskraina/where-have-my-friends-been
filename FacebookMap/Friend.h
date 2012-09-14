//
//  Friend.h
//  FacebookMap
//
//  Created by Tom Kraina on 14.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class LocationObject;

@interface Friend : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSSet *locations;
@end

@interface Friend (CoreDataGeneratedAccessors)

- (void)addLocationsObject:(LocationObject *)value;
- (void)removeLocationsObject:(LocationObject *)value;
- (void)addLocations:(NSSet *)values;
- (void)removeLocations:(NSSet *)values;
@end
