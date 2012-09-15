//
//  PlaceMapAnnotation.m
//  FacebookMap
//
//  Created by Tom Kraina on 15.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "PlaceMapAnnotation.h"

@interface PlaceMapAnnotation()
@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *subtitle;
@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (strong, nonatomic) NSDictionary *infoDictionary;
@end

@implementation PlaceMapAnnotation
@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize coordinate = _coordinate;
@synthesize infoDictionary = _infoDictionary;

- (id)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle coordinate:(CLLocationCoordinate2D)coordinate info:(NSDictionary *)info
{
    self = [super init];
    if (self) {
        self.title = title;
        self.subtitle = subtitle;
        self.coordinate = coordinate;
        self.infoDictionary = info;
    }
    return self;
}
@end
