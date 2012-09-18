//
//  Location+Creation.h
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Location.h"
#import <FacebookSDK/FacebookSDK.h>

@interface Location (Creation)

+ (Location *)locationWithFacebookInfo:(NSDictionary<FBGraphPlace> *)placeInfo
                inManagedObjectContext:(NSManagedObjectContext *)context;

@end
