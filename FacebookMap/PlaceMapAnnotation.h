//
//  PlaceMapAnnotation.h
//  FacebookMap
//
//  Created by Tom Kraina on 15.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface PlaceMapAnnotation : NSObject <MKAnnotation>
@property (strong, nonatomic, readonly) NSDictionary *infoDictionary;
- (id)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle coordinate:(CLLocationCoordinate2D)coordinate info:(NSDictionary *)info;
@end
