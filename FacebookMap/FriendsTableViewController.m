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

@interface FriendsTableViewController () <UITableViewDataSource, UITableViewDelegate>
@property (strong, nonatomic) NSArray *friends;
@property (strong, nonatomic, readonly) NSArray *sectionedFriends;
@property (strong, nonatomic) NSMutableDictionary *locations;
@property (strong, nonatomic) UILocalizedIndexedCollation *collation;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation FriendsTableViewController

@synthesize detailViewController = _detailViewController;
@synthesize fetchedResultsController = __fetchedResultsController;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize friends = _friends;
@synthesize sectionedFriends = _sectionedFriends;
@synthesize locations = _locations;
@synthesize collation = _collation;

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
    if (_friends != friends) {
        _friends = friends;
        
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
    self.navigationItem.leftBarButtonItem = logoutButton;
}

- (void)performLogout:(id)sender
{
    [TestFlight passCheckpoint:@"tap logout"];
    FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate facebookCloseSession];
}

- (void)refreshMapWithNewLocations:(NSArray *)locations forUser:(NSDictionary<FBGraphUser> *)user
{
    [self.detailViewController addLocations:locations forUser:user];
}

- (void)fetchLocationsForAllFriends
{
    NSMutableDictionary *allLocations = self.locations;
    for (NSMutableDictionary<FBGraphUser> *user in self.friends) {
        FBRequestConnection *connection = [[FBRequestConnection alloc] initWithTimeout:15]; // TODO: review the value
        FBRequest *request = [FBRequest requestForGraphPath:[user.id stringByAppendingString:@"/locations"]];
        [connection addRequest:request completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (!error && result) {
                [TestFlight passCheckpoint:@"locations fetched"];
                NSArray *locations = [result objectForKey:@"data"];
                [allLocations setObject:locations forKey:user.id];
                [self refreshMapWithNewLocations:locations forUser:user];
            }
            else {
                // TODO: do something with the error
                NSLog(@"Error during fetching locations: %@", error);
                
            }
        }];
        [connection start];
    }
}

- (void)fetchFriends
{
//    [FBSettings setLoggingBehavior:[NSSet setWithObjects:FBLoggingBehaviorFBRequests, nil]];
    FBRequest *request = [FBRequest requestForMyFriends];
    FBRequestConnection *connection = [[FBRequestConnection alloc] initWithTimeout:30]; // TODO: review the timeout value
    [connection addRequest:request completionHandler:^(FBRequestConnection *connection, id result, NSError *error){
        if (!error && result) {
            [TestFlight passCheckpoint:@"friends fetched"];
            
            self.friends = [result objectForKey:@"data"];
            [self.tableView reloadData];
            
            [self fetchLocationsForAllFriends];
        }
        else {
            NSLog(@"Error during fetching friends: %@", error);
            // TODO: show error message
        }
    }];
    
    [connection start];
}

- (void)facebookSessionStateChanged:(NSNotification*)notification {
    if (FBSession.activeSession.isOpen) {
        [self fetchFriends];
        
        // Show the logout button
        if (!self.navigationItem.leftBarButtonItem) {
            [self setUpLogoutButton];
        }
    } else {
        // hide the logout button
        self.navigationItem.leftBarButtonItem = nil;
        
        // delete friends list
        self.friends = nil;
        [self.tableView reloadData];
        
        // TODO: stop all running requests
    }
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.detailViewController = (MapViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

    // TODO: set up refresh button
    
    // Collation object
    self.collation = [UILocalizedIndexedCollation currentCollation];
    
    // Register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(facebookSessionStateChanged:) name:FBSessionStateChangedNotification object:nil];
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
//    return [self.sections objectAtIndex:section];

    BOOL showSection = [[self.sectionedFriends objectAtIndex:section] count] != 0;
    //only show the section title if there are rows in the section
    return (showSection) ? [self.collation.sectionTitles objectAtIndex:section] : nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
//    return [[self.fetchedResultsController sections] count];
//    return self.sections.count;
    return self.collation.sectionTitles.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
//    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
//    return [sectionInfo numberOfObjects];
//    NSString *key = [self.sections objectAtIndex:section];
//    return [[self.sectionedFriends objectForKey:key] count];
    return [[self.sectionedFriends objectAtIndex:section] count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Friend Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        // cell didn't load from the storyboard prototype
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        // ..
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    NSManagedObject *selectedObject = [[self fetchedResultsController] objectAtIndexPath:indexPath];
//    self.detailViewController.detailItem = selectedObject;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
//    NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];

    NSMutableDictionary<FBGraphUser> *user = [[self.sectionedFriends objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    cell.textLabel.text = user.name;
    cell.detailTextLabel.text = user.location.name; // TODO: set last known location
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return self.collation.sectionIndexTitles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    //sectionForSectionIndexTitleAtIndex: is a bit buggy, but is still useable
    return [self.collation sectionForSectionIndexTitleAtIndex:index];
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
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:NO];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
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

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

- (void)insertNewObject
{
    // Create a new instance of the entity managed by the fetched results controller.
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
    
    // If appropriate, configure the new managed object.
    // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
    [newManagedObject setValue:[NSDate date] forKey:@"timeStamp"];
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}

@end
