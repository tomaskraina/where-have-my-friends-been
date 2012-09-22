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
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    return [NSString stringWithFormat:@"%@ on %@", self.location.name, [dateFormatter stringFromDate:self.created_time]];
}

@end
