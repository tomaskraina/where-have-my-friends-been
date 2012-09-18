//
//  Checkin.h
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Friend, Location;

@interface Checkin : NSManagedObject

@property (nonatomic, retain) NSDate * created_time;
@property (nonatomic, retain) NSString * from_id;
@property (nonatomic, retain) NSString * from_name;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) Location *location;
@property (nonatomic, retain) NSSet *whoHasBeenThere;
@end

@interface Checkin (CoreDataGeneratedAccessors)

- (void)addWhoHasBeenThereObject:(Friend *)value;
- (void)removeWhoHasBeenThereObject:(Friend *)value;
- (void)addWhoHasBeenThere:(NSSet *)values;
- (void)removeWhoHasBeenThere:(NSSet *)values;

@end
