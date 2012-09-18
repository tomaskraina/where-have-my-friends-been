//
//  MapViewController.h
//  FacebookMap
//
//  Created by Tom Kraina on 14.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FacebookSDK/FacebookSDK.h>

@class Friend;

@interface MapViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;

- (void)addLocations:(NSArray *)locations forUser:(Friend *)user;
- (void)startDownloadingLocationsForUsers:(NSArray *)users;

@end
