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
@class FriendsTableViewController;

@interface MapViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;
@property (strong, nonatomic) FriendsTableViewController *friendViewController;

- (void)startFetchingCheckinsForFriends:(NSArray *)users;
- (void)reloadAnnotationsFromCoreData;

@end
