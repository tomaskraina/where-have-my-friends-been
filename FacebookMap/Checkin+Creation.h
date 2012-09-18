//
//  Checkin+Creation.h
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Checkin.h"

@class Friend;

@interface Checkin (Creation)

+ (Checkin *)checkinWithFacebookInfo:(NSDictionary *)checkinInfo
                             forUser:(Friend *)user
              inManagedObjectContext:(NSManagedObjectContext *)context;

@end
