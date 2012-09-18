//
//  Friend.h
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Checkin;

@interface Friend : NSManagedObject

@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * username;
@property (nonatomic, retain) NSSet *locations;
@end

@interface Friend (CoreDataGeneratedAccessors)

- (void)addLocationsObject:(Checkin *)value;
- (void)removeLocationsObject:(Checkin *)value;
- (void)addLocations:(NSSet *)values;
- (void)removeLocations:(NSSet *)values;

@end
