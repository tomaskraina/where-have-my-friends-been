//
//  MapViewController.m
//  FacebookMap
//
//  Created by Tom Kraina on 14.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "MapViewController.h"
#import "PlaceMapAnnotation.h"
#import <MapKit/MapKit.h>
#import "FacebookMapAppDelegate.h"
#import "TestFlight.h"
#import "FileCache.h"
#import "Friend.h"
#import "Checkin+Creation.h"
#import "Checkin+MapAnnotation.h"

#define PAGING_LIMIT 30

@interface MapViewController () <MKMapViewDelegate>
@property (strong, nonatomic) NSMutableDictionary *locations;
@property (strong, nonatomic) NSDictionary *users;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (weak, nonatomic) IBOutlet UIView *loadingView;
@property (nonatomic) NSInteger numberOfRunningRequests;
@property (strong, nonatomic) FileCache *cache;
@property (nonatomic) NSInteger numberOfLocations;
@property (strong, nonatomic) NSDate *startTime;

@property (nonatomic) BOOL isFetchingAllowed;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
- (void)configureView;
@end

@implementation MapViewController

@synthesize detailItem = _detailItem;
@synthesize mapView = _mapView;
@synthesize masterPopoverController = _masterPopoverController;
@synthesize locations = _locations;
@synthesize numberOfRunningRequests = _numberOfRunningRequests;
@synthesize cache = _cache;
@synthesize numberOfLocations = _numberOfLocations;
@synthesize startTime = _startTime;
@synthesize isFetchingAllowed = _isFetchingAllowed;
@synthesize managedObjectContext = _managedObjectContext;


- (FileCache *)cache
{
    if (!_cache) {
        _cache = [[FileCache alloc] init];
        _cache.maxSize = 10;
        _cache.domain = @"thumbnails";
    }
    return  _cache;
}

- (NSMutableDictionary *)locations
{
    if (!_locations) {
        _locations = [NSMutableDictionary dictionary];
    }
    
    return _locations;
}


- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        return appDelegate.managedObjectContext;
    }

    return _managedObjectContext;
}

// thread-safe
// Can be called from another thread
- (void)reloadAnnotationsFromCoreData
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(reloadAnnotationsFromCoreData) withObject:nil waitUntilDone:YES];
        return;
    }
    
    NSLog(@"Refreshing map annotations from CoreData...");
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Checkin"];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    request.predicate = nil;
    
    NSError *error;
    NSArray *locations = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    if (locations.count > 0) {
        NSLog(@"Adding %i locations on the map.", locations.count);
        
//        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mapView addAnnotations:locations];
//        });
    }
    else if (locations) {
        // TODO: Start fetching locations for users?
    }
    else {
        // TODO: handle error
    }
}

static NSTimeInterval AnimationDuration = 1;

- (void)showLoadingViewAnimated
{
    self.loadingView.hidden = NO;
    [UIView transitionWithView:self.loadingView duration:AnimationDuration options:UIViewAnimationOptionLayoutSubviews animations:^{
        //        self.loadingView.alpha = 1;
        CGRect frame = self.loadingView.frame;
        frame.origin.y += frame.size.height;
        self.loadingView.frame = frame;
    } completion:nil];
}

- (void)hideLoadingViewAnimated
{
    [UIView transitionWithView:self.loadingView duration:AnimationDuration options:UIViewAnimationOptionLayoutSubviews animations:^{
        CGRect frame = self.loadingView.frame;
        frame.origin.y -= frame.size.height;
        self.loadingView.frame = frame;
    } completion:^(BOOL finished){
        if (finished) {
            self.loadingView.hidden = YES;
        }
    }];
}


- (void)setNumberOfRunningRequests:(NSInteger)numberOfRunningRequests
{
    if (numberOfRunningRequests == 0 && self.loadingView.hidden == NO) {
        [self hideLoadingViewAnimated];
        
        NSLog(@"Stop time: %@", [NSDate date]);
        NSLog(@"Total %i locations have been harvested", self.numberOfLocations);
        NSLog(@"Total time %f seconds", [[NSDate date] timeIntervalSinceDate:self.startTime]);
    }
    
    _numberOfRunningRequests = numberOfRunningRequests;
    
}

#pragma mark - Managing the detail item

- (void)didFetchAllCheckinsForFriend:(Friend *)friend
{
    NSLog(@"All locations for friend=%@ has been imported", friend.name);
}

- (void)didFailFetchingCheckinsForFriend:(Friend *)friend error:(NSError *)error
{
    NSLog(@"Error: Can't download locations for friend %@ : %@", friend.name, error.debugDescription);
}

// Run this only on the main thread
- (void)fetchCheckinsIntoCoreDataForFriend:(Friend *)friend limit:(NSInteger)limit offset:(NSInteger)offset
{
    if (!self.isFetchingAllowed) return;
    
    NSString *graphPath = [NSString stringWithFormat:@"%@/locations?limit=%i&offset=%i", friend.id, limit, offset];
    FBRequest *request = [FBRequest requestForGraphPath:graphPath];
    [request startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        self.numberOfRunningRequests--;
        if (!self.isFetchingAllowed) return;
        
        if (result && !error) {
            // add to data store
            NSLog(@"Processing locations... (limit=%i, offset=%i, friend=%@)", limit, offset, friend.name);
            NSArray *checkins = [result objectForKey:@"data"];
            if (checkins.count > 0) {
                
                // Import and save CoreData in the background
                // It creates it's own context
                dispatch_queue_t queue = dispatch_queue_create("location importer", NULL);
                dispatch_async(queue, ^{
                    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] init];
                    FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                    context.persistentStoreCoordinator = appDelegate.persistentStoreCoordinator;
                    for (NSDictionary<FBGraphObject> *checkin in checkins) {
                        [Checkin checkinWithFacebookInfo:checkin forUser:friend inManagedObjectContext:context];
                    }
                    
                    // save context
                    NSError *error;
                    if (![context save:&error]) {
                        // NOTE: Handle error?
                        NSLog(@"Error: Couldn't save locations (limit=%i, offset=%i, friend=%@)", limit, offset, friend.name);
                        NSLog(@"Error: description: %@", [error debugDescription]);
                    }
                    
                    NSLog(@"Imported %i locations (limit=%i, offset=%i, friend=%@)", checkins.count, limit, offset, friend.name);
                    
                    // Notify mapview to reload its data
                    [self reloadAnnotationsFromCoreData];
                });
                
                // check for additional data (recursion)
                if ([[result objectForKey:@"paging"] objectForKey:@"next"]) {
                    [self fetchCheckinsIntoCoreDataForFriend:friend limit:limit offset:offset+limit];
                }
                else {
                    // this was the last page
                    [self didFetchAllCheckinsForFriend:friend];
                }
            }
            else {
                // this was the last page
                [self didFetchAllCheckinsForFriend:friend];
            }
        }
        else {
            [self didFailFetchingCheckinsForFriend:friend error:error];
        }
    }];
    self.numberOfRunningRequests++;
}

- (void)startFetchingCheckinsIntoCoreDataForFriend:(Friend *)friend
{
    if (!self.isFetchingAllowed) return;
    [self fetchCheckinsIntoCoreDataForFriend:friend limit:PAGING_LIMIT offset:0];
}

- (void)startFetchingCheckinsForFriends:(NSArray *)friends
{    
    // show loading view
    [self showLoadingViewAnimated];
    
    // start counting
    self.startTime = [NSDate date];
    NSLog(@"Start time: %@", self.startTime);
    NSLog(@"Paging limit = %i", PAGING_LIMIT);
    
    self.isFetchingAllowed = YES;
    for (Friend *friend in friends) {
        [self startFetchingCheckinsIntoCoreDataForFriend:friend];
    }
}


- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }        
}

- (void)configureView
{
    // Update the user interface for the detail item.

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}


- (IBAction)deleteCoreData:(id)sender {
    
    // TODO: Stop all runnin' requests!
    // use dispatch_group ?
    self.isFetchingAllowed = NO;
    
    // Should be always on the main thread (since it's called from UI)
    FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate deleteCoreData];
}

#pragma mark - TestFlight
- (IBAction)launchFeedback {
    [TestFlight openFeedbackView];
}

#pragma mark - Facebook
- (void)showLoginScreen
{
    [self performSegueWithIdentifier:@"login" sender:self];
}

- (void)facebookSessionStateChanged:(NSNotification*)notification {
    if (FBSession.activeSession.isOpen) {
        [self dismissModalViewControllerAnimated:YES];
    }
    else {
        [self showLoginScreen];
        
        // TODO: stop all running requests
        
        // delete anotations on the map
        [self.mapView removeAnnotations:self.mapView.annotations];
    }
}

#pragma mark - UIStoryboardSegue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.numberOfLocations = 0;
    self.numberOfRunningRequests = 0;
    self.isFetchingAllowed = NO;
    
	// Do any additional setup after loading the view, typically from a nib.
    [self configureView];
    
    // Register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(facebookSessionStateChanged:) name:FBSessionStateChangedNotification object:nil];
    
    // Check the session for a cached token to show the proper authenticated
    // UI. However, since this is not user intitiated, do not show the login UX.
    FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate facebookOpenSessionWithAllowLoginUI:NO];
}

- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setMapView:nil];
    [self setLoadingView:nil];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // See if we have a open session
    if (!FBSession.activeSession.isOpen) {
        [self showLoginScreen];
    }
    else {
        // try to get cached location objects
        [self reloadAnnotationsFromCoreData];
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

#pragma mark - Split view

- (BOOL)splitViewController:(UISplitViewController *)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
{
    return YES;
}

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    [TestFlight passCheckpoint:@"portrait"];
    barButtonItem.title = NSLocalizedString(@"Friends", @"Friends");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    NSMutableArray *toolbarItems = [self.toolbarItems mutableCopy];
    [toolbarItems insertObject:barButtonItem atIndex:0];
    self.toolbarItems = toolbarItems;
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    [TestFlight passCheckpoint:@"landscape"];
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    NSMutableArray *toolbarItems = [self.toolbarItems mutableCopy];
    [toolbarItems removeObject:barButtonItem];
    self.toolbarItems = toolbarItems;
    self.masterPopoverController = nil;
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    static NSString *Identifier = @"Place Annotation";
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:Identifier];
    if (!annotationView) {
        annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:Identifier];
//        annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        annotationView.leftCalloutAccessoryView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
        annotationView.canShowCallout = YES;
    }
    
    return annotationView;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    dispatch_queue_t queue = dispatch_queue_create("profile picture downloader", NULL);
    dispatch_async(queue, ^{
        NSDictionary<FBGraphUser> *user = (NSDictionary<FBGraphUser>*)[(PlaceMapAnnotation *)view.annotation infoDictionary];
        NSData *imageData = [self.cache dataForKey:user.id];
        
        if (!imageData) {
            // download
            NSURL *url = [NSURL URLWithString:[FBGraphBasePath stringByAppendingFormat:@"/%@/picture?type=%@", user.id, @"square"]];
            imageData = [NSData dataWithContentsOfURL:url];
            [self.cache saveData:imageData forKey:user.id];
        }
        
        UIImage *image = [UIImage imageWithData:imageData];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(UIImageView *)view.leftCalloutAccessoryView setImage:image];
        });
    });
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    // fire segue
//    [self performSegueWithIdentifier:@"Show photos at location" sender:view];
    
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
//    if (self.selectedPlace) {
//        for (MKAnnotationView *view in views) {
//            MapAnnotation *annotation = (MapAnnotation *)view.annotation;
//            if ([annotation.infoDictionary isEqualToDictionary:self.selectedPlace]) {
//                [self.mapView selectAnnotation:annotation animated:YES];
//                break;
//            }
//        }
//    }
}

@end
