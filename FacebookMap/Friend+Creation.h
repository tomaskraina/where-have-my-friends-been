//
//  Friend+Creation.h
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Friend.h"
#import <FacebookSDK/FacebookSDK.h>

@interface Friend (Creation)

+ (Friend *)friendWithFacebookInfo:(NSDictionary<FBGraphUser> *)userInfo
            inManagedObjectContext:(NSManagedObjectContext *)context;

@end
