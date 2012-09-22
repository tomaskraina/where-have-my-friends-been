//
//  FriendsTableViewController.h
//  FacebookMap
//
//  Created by Tom Kraina on 14.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class MapViewController;
@class FileCache;

@interface FriendsTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) MapViewController *detailViewController;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic, readonly) FileCache *cache;

- (void)startFetchingUsersIntoCoreData;

@end
