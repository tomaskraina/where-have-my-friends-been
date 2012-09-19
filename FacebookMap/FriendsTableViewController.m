//
//  FriendsTableViewController.m
//  FacebookMap
//
//  Created by Tom Kraina on 14.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "FriendsTableViewController.h"
#import "MapViewController.h"
#import "FacebookMapAppDelegate.h"
#import <FacebookSDK/FacebookSDK.h>
#import "FileCache.h"
#import "Friend.h"
#import "Friend+Creation.h"
#import "Checkin.h"
#import "Location.h"

@interface FriendsTableViewController () <UITableViewDataSource, UITableViewDelegate>
@property (strong, nonatomic) NSArray *friends;
@property (strong, nonatomic, readonly) NSArray *sectionedFriends;
@property (strong, nonatomic) NSMutableDictionary *locations;
@property (strong, nonatomic) UILocalizedIndexedCollation *collation;
@property (strong, nonatomic) FileCache *cache;
@property (nonatomic) BOOL isLoadingFriends;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation FriendsTableViewController

@synthesize detailViewController = _detailViewController;
@synthesize fetchedResultsController = __fetchedResultsController;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize friends = _friends;
@synthesize sectionedFriends = _sectionedFriends;
@synthesize locations = _locations;
@synthesize cache = _cache;

- (FileCache *)cache
{
    if (!_cache) {
        _cache = [[FileCache alloc] init];
        _cache.maxSize = 10;
        _cache.domain = @"thumbnails";
    }
    return  _cache;
}

- (UILocalizedIndexedCollation *)collation
{
    if (!_collation) {
        _collation = [UILocalizedIndexedCollation currentCollation];
    }
    
    return _collation;
}

- (NSArray *)sectionedFriends
{
    if (!_sectionedFriends) {
        NSInteger sectionCount = [[self.collation sectionTitles] count];
        NSMutableArray *unsortedSections = [NSMutableArray arrayWithCapacity:sectionCount];
        
        // create an array to hold the date for each section
        for (NSInteger i = 0; i < sectionCount; i++) {
            [unsortedSections addObject:[NSMutableArray array]];
        }
        
        // put each model object into a section
        for (NSMutableArray<FBGraphUser> *user in self.friends) {
            NSInteger sectionIndex = [self.collation sectionForObject:user collationStringSelector:@selector(name)];
            [[unsortedSections objectAtIndex:sectionIndex] addObject:user];
        }
        
        // sort each section
        NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
        for (NSArray *section in unsortedSections) {
            [sections addObject:[self.collation sortedArrayFromArray:section collationStringSelector:@selector(name)]];
        }
        
        _sectionedFriends = sections;
    }
    
    return _sectionedFriends;
}


- (void)setFriends:(NSArray *)friends
{
    self.isLoadingFriends = NO;
    
    if (_friends != friends) {
        _friends = friends;
        
        dispatch_queue_t save_queue = dispatch_queue_create("coredata saver", NULL);
        dispatch_async(save_queue, ^{
            NSDate *start = [NSDate date];
            NSLog(@"Creating Managed Objects for friends...");
            NSManagedObjectContext *context = [[NSManagedObjectContext alloc] init];
            FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            context.persistentStoreCoordinator = appDelegate.persistentStoreCoordinator;
            
            // Load friend into CoreData
            for (NSDictionary<FBGraphUser> *user in friends) {
                [Friend friendWithFacebookInfo:user inManagedObjectContext:context];
            }
            
            // Save the context.
            NSLog(@"Saving friends...");
            NSError *error = nil;
            if (![context save:&error]) {
                // TODO: get rid of abort()
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
            NSLog(@"Friends created and saved in %f seconds", [[NSDate date] timeIntervalSinceDate:start]);
        });
        
        // invalidate dependent properties
        _sectionedFriends = nil;
    }
}

- (void)awakeFromNib
{
    self.clearsSelectionOnViewWillAppear = NO;
    self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    [super awakeFromNib];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)setUpLogoutButton
{
    UIBarButtonItem *logoutButton = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStyleBordered target:self action:@selector(performLogout:)];
    self.navigationItem.rightBarButtonItem = logoutButton;
}


#pragma mark - Facebook-related methods

- (void)performLogout:(id)sender
{
    [TestFlight passCheckpoint:@"tap logout"];
    FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate facebookCloseSession];
}

- (void)fetchLocationsForAllFriends
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:NO];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    NSError *error;
    NSArray *friends = [self.managedObjectContext executeFetchRequest:request error:&error];
//    friends = [friends subarrayWithRange:NSMakeRange(0, 30)];
    [self.detailViewController startDownloadingLocationsForUsers:friends];
}

- (void)fetchFriendsInContext:(NSManagedObjectContext *)context
{
    // TODO: Uncomment to show activity indicator
//    self.isLoadingFriends = YES;
    
    // Delay execution of my block
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
    NSDate *start = [NSDate date];
        FBRequest *request = [FBRequest requestForMyFriends];
        FBRequestConnection *connection = [[FBRequestConnection alloc] initWithTimeout:30]; // TODO: review the timeout value
        [connection addRequest:request completionHandler:^(FBRequestConnection *connection, id result, NSError *error){
            if (!error && result) {
                NSLog(@"Friends downloaded from Facebook in %f seconds", [[NSDate date] timeIntervalSinceDate:start]);
                [TestFlight passCheckpoint:@"friends fetched"];
                
                // Load friends into Core Data
                self.friends = [result objectForKey:@"data"];
            }
            else {
                NSLog(@"Error during fetching friends: %@", error);
                // TODO: show error message (A view probably) and refresh button!
            }
        }];
        [connection start];
//    });
}

- (void)facebookSessionStateChanged:(NSNotification*)notification {
    if (FBSession.activeSession.isOpen) {
        NSArray *fetchedObjects = [self.fetchedResultsController fetchedObjects];
        if ([fetchedObjects count] == 0) {
            [self fetchFriendsInContext:self.managedObjectContext];
        }
        else {
            // TODO: tell MapViewController to refresh its location objects
            [self fetchLocationsForAllFriends];
        }
        
        // Show the logout button
        if (!self.navigationItem.rightBarButtonItem) {
            [self setUpLogoutButton];
        }
    } else {
        // hide the logout button
        self.navigationItem.rightBarButtonItem = nil;
        
        // TODO: delete friends list
        self.friends = nil;
        [self.tableView reloadData];
        
        // TODO: stop all running requests
    }
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.isLoadingFriends = NO;
    
	// Do any additional setup after loading the view, typically from a nib.
    self.detailViewController = (MapViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

    // TODO: set up refresh button
    
    // Register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(facebookSessionStateChanged:) name:FBSessionStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contentChanged:) name:NSManagedObjectContextDidSaveNotification object:nil];
}

- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}


#pragma mark - UITableViewDataSource & UITableViewDelegate

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self.isLoadingFriends) {
        return nil;
    }
    else {
        // UILocalizeIndexedCollation
//        BOOL showSection = [[self.sectionedFriends objectAtIndex:section] count] != 0;
//        //only show the section title if there are rows in the section
//        return (showSection) ? [self.collation.sectionTitles objectAtIndex:section] : nil;
        
        // CoreData
        return [[self.fetchedResultsController sectionIndexTitles] objectAtIndex:section];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.isLoadingFriends) {
        return 1;
    }
    else {
        // UILocalizedIndexedCollation
//        return self.collation.sectionTitles.count;
        
        // CoreData
        return [[self.fetchedResultsController sections] count];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.isLoadingFriends) {
        return 1;
    }
    else {
        // UILocalizedIndexedCollation
//        return [[self.sectionedFriends objectAtIndex:section] count];

        // CoreData
        id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
        return [sectionInfo numberOfObjects];
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    static NSString *LoadingCellIdentifier = @"Loading Cell";
    static NSString *FriendCellIdentifier = @"Friend Cell";
    
    if (self.isLoadingFriends) {
        cell = [tableView dequeueReusableCellWithIdentifier:LoadingCellIdentifier];
        if (!cell) {
            // cell didn't load from the storyboard prototype
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:LoadingCellIdentifier];
            cell.textLabel.text = @"Loading friends...";
        }
    }
    else {
        cell = [tableView dequeueReusableCellWithIdentifier:FriendCellIdentifier];
        if (!cell) {
            // cell didn't load from the storyboard prototype
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:FriendCellIdentifier];
        }
        [self configureCell:cell atIndexPath:indexPath];
    }
    return cell;
}

//- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    NSManagedObject *selectedObject = [[self fetchedResultsController] objectAtIndexPath:indexPath];
//    self.detailViewController.detailItem = selectedObject;
//}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    // UILocalizedIndexedCollation & Facebook
//    NSMutableDictionary<FBGraphUser> *user = [[self.sectionedFriends objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
//    cell.textLabel.text = user.name;
//    cell.detailTextLabel.text = user.location.name; // TODO: set last known location
    
    // CoreData
    Friend *user = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = user.name;
    cell.detailTextLabel.text = ((Checkin *)user.locations.anyObject).location.name; // TODO: get the last known location

    cell.imageView.image = nil;
    cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    
    dispatch_queue_t queue = dispatch_queue_create("profile picture downloader", NULL);
    dispatch_async(queue, ^{
        NSData *imageData = [self.cache dataForKey:user.id];
        
        if (!imageData) {
            NSURL *url = [NSURL URLWithString:[FBGraphBasePath stringByAppendingFormat:@"/%@/picture?type=%@", user.id, @"square"]];
            imageData = [NSData dataWithContentsOfURL:url];
            [self.cache saveData:imageData forKey:user.id];
        }
        
        UIImage *image = [UIImage imageWithData:imageData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            cell.imageView.image = image;
        });
    });
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    // UILocalizedIndexedCollation
//    return self.collation.sectionIndexTitles;
    
    // CoreData
    return [self.fetchedResultsController sectionIndexTitles];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    // UILocalizedIndexedCollation
//    return [self.collation sectionForSectionIndexTitleAtIndex:index];
    
    // CoreData
    return [self.fetchedResultsController sectionForSectionIndexTitle:title atIndex:index];
}



#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (__fetchedResultsController != nil) {
        return __fetchedResultsController;
    }
    
    // Set up the fetched results controller.
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Friend" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Set up sort descriptors.
    // Use localizedStandardCompare: (http://stackoverflow.com/questions/7199934/nsfetchedresultscontroller-v-s-uilocalizedindexedcollation)
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:@"sectionName" cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	    /*
	     Replace this implementation with code to handle the error appropriately.

	     abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	     */
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return __fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

- (void)contentChanged:(NSNotification *)notification
{
    if ([notification object] == [self managedObjectContext]) return;
    
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(contentChanged:) withObject:notification waitUntilDone:YES];
        return;
    }
    
    [[self managedObjectContext] mergeChangesFromContextDidSaveNotification:notification];
    
    // Friends are ready to go => Start loading locations
    [self fetchLocationsForAllFriends];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */


@end
