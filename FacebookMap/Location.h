//
//  Location.h
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Checkin;

@interface Location : NSManagedObject

@property (nonatomic, retain) NSString * city;
@property (nonatomic, retain) NSString * country;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet *checkins;
@end

@interface Location (CoreDataGeneratedAccessors)

- (void)addCheckinsObject:(Checkin *)value;
- (void)removeCheckinsObject:(Checkin *)value;
- (void)addCheckins:(NSSet *)values;
- (void)removeCheckins:(NSSet *)values;

@end
