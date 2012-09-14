//
//  LocationObject.h
//  FacebookMap
//
//  Created by Tom Kraina on 14.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface LocationObject : NSManagedObject

@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * from_name;
@property (nonatomic, retain) NSString * from_id;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSDate * created_time;
@property (nonatomic, retain) NSManagedObject *whoHasBeenThere;
@property (nonatomic, retain) NSManagedObject *place;

@end
