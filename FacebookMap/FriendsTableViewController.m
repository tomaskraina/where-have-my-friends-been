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
@property (strong, nonatomic, readonly) NSMutableDictionary *sectionedFriends;
@property (strong, nonatomic, readonly) NSArray *sections;
@property (strong, nonatomic) NSMutableDictionary *locations;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation FriendsTableViewController

@synthesize detailViewController = _detailViewController;
@synthesize fetchedResultsController = __fetchedResultsController;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize friends = _friends;
@synthesize sectionedFriends = _sectionedFriends;
@synthesize sections = _sections;
@synthesize locations = _locations;

- (NSDictionary *)sectionedFriends
{
    if (!_sectionedFriends) {
        _sectionedFriends = [NSMutableDictionary dictionary];
        
        for (NSDictionary<FBGraphUser> *user in self.friends) {
            NSString *firstLetter = [user.first_name substringToIndex:1];
            
            NSMutableArray *arrayForFirsLetter = [_sectionedFriends objectForKey:firstLetter];
            if (!arrayForFirsLetter) {
                arrayForFirsLetter = [NSMutableArray array];
            }
            [arrayForFirsLetter addObject:user];
            [_sectionedFriends setObject:arrayForFirsLetter forKey:firstLetter];
        }
    }
    
    return _sectionedFriends;
}

- (NSArray *)sections
{
    if (!_sections) {
        _sections = [self.sectionedFriends.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    }
    
    return _sections;
}

- (void)setFriends:(NSArray *)friends
{
    // sort array
    _friends = [friends sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2){
        return [[obj1 objectForKey:@"name"] compare:[obj2 objectForKey:@"name"] options:NSCaseInsensitiveSearch];
    }];
    
    // invalidate dependent properties
    _sectionedFriends = nil;
    _sections = nil;
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

- (void)showLoginScreen
{
    [self performSegueWithIdentifier:@"login" sender:self];
}

- (void)setUpLogoutButton
{
    UIBarButtonItem *logoutButton = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStyleBordered target:self action:@selector(performLogout:)];
    self.navigationItem.leftBarButtonItem = logoutButton;
}

- (void)facebookDidLogOut:(id)sender
{
    // hide the logout button
    self.navigationItem.leftBarButtonItem = nil;
    
    [self showLoginScreen];
}

- (void)facebookDidLogIn:(id)sender
{
    // dismiss login view
    [self dismissModalViewControllerAnimated:YES];
    
    [self setUpLogoutButton];
}

- (void)performLogout:(id)sender
{
    [FBSession.activeSession closeAndClearTokenInformation];
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
    [FBSettings setLoggingBehavior:[NSSet setWithObjects:FBLoggingBehaviorFBRequests, nil]];
    FBRequest *request = [FBRequest requestForMyFriends];
    FBRequestConnection *connection = [[FBRequestConnection alloc] initWithTimeout:30]; // TODO: review the timeout value
    [connection addRequest:request completionHandler:^(FBRequestConnection *connection, id result, NSError *error){
        if (!error && result) {
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

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.detailViewController = (MapViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

    // TODO: set up refresh button
    
    // Register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(facebookDidLogIn:) name:@"FBSessionStateOpenNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(facebookDidLogOut:) name:@"FBSessionStateClosedNotification" object:nil];
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
    
    // See if we have a valid token for the current state.
    if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
        // Yes, so just open the session (this won't display any UX).
        // TODO: refactor, this is an antipattern
        FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate facebookOpenSession];
        
        // Show the logout button
        if (!self.navigationItem.leftBarButtonItem) {
            [self setUpLogoutButton];
        }
        
        [self fetchFriends];
        
    } else {
        // No, display the login page.
        [self showLoginScreen];
    }
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

#pragma mark - UIStoryboardSegue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
}


#pragma mark - UITableViewDataSource & UITableViewDelegate

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [self.sections objectAtIndex:section];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
//    return [[self.fetchedResultsController sections] count];
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
//    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
//    return [sectionInfo numberOfObjects];
    NSString *key = [self.sections objectAtIndex:section];
    return [[self.sectionedFriends objectForKey:key] count];
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
    NSManagedObject *selectedObject = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    self.detailViewController.detailItem = selectedObject;    
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
//    NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];

    NSString *key = [self.sections objectAtIndex:indexPath.section];
    NSMutableDictionary<FBGraphUser> *user = [[self.sectionedFriends objectForKey:key] objectAtIndex:indexPath.row];
    cell.textLabel.text = user.name;
    cell.detailTextLabel.text = user.location.name; // TODO: set last known location
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
