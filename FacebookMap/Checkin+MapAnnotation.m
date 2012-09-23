//
//  Checkin+MapAnnotation.m
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Checkin+MapAnnotation.h"
#import "Location.h"
#import "Friend.h"

@implementation Checkin (MapAnnotation)

+ (NSDateFormatter *)sharedDateFormatter
{
    static dispatch_once_t once;
    static NSDateFormatter *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[NSDateFormatter alloc] init];
        sharedInstance.timeStyle = NSDateFormatterShortStyle;
        sharedInstance.dateStyle = NSDateFormatterMediumStyle;
    });
    return sharedInstance;
}

- (CLLocationCoordinate2D)coordinate
{
    return CLLocationCoordinate2DMake([self.location.latitude doubleValue], [self.location.longitude doubleValue]);
}

- (NSString *)title
{
    Friend *user = [self.whoHasBeenThere anyObject];
    
    if (self.whoHasBeenThere.count == 2) {
        return [NSString stringWithFormat:@"%@ + 1 more", user.name];
    }
    else if (self.whoHasBeenThere.count > 2) {
        return [NSString stringWithFormat:@"%@ + %i others", user.name, self.whoHasBeenThere.count - 1];
    }
    else {
        return user.name;
    }
}

-(NSString *)subtitle
{
    return [NSString stringWithFormat:@"%@ on %@", self.location.name, [[Checkin sharedDateFormatter] stringFromDate:self.created_time]];
}

@end
