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

- (void)reloadAnnotationsFromCoreData
{
    FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Checkin"];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    request.predicate = nil;
    
    NSError *error;
    NSArray *locations = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    
    if (locations.count > 0) {
        NSLog(@"Adding %i locations on the map.", locations.count);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mapView addAnnotations:locations];
        });
    }
    else {
        // TODO: Start fetching locations for users?
    }
}

static NSTimeInterval AnimationDuration = 1;

- (void)setNumberOfRunningRequests:(NSInteger)numberOfRunningRequests
{
    if (numberOfRunningRequests == 0 && self.loadingView.hidden == NO) {
        // hide loading view
        NSLog(@"Stop time: %@", [NSDate date]);
        NSLog(@"Total %i locations have been harvested", self.numberOfLocations);
        NSLog(@"Total time %f seconds", [[NSDate date] timeIntervalSinceDate:self.startTime]);
        [UIView transitionWithView:self.loadingView duration:AnimationDuration options:UIViewAnimationOptionLayoutSubviews animations:^{
            CGRect frame = self.loadingView.frame;
            frame.origin.y -= frame.size.height;
            self.loadingView.frame = frame;
        } completion:^(BOOL finished){
            if (finished) {
                self.loadingView.hidden = YES;
            }
        }];
        
        // this adds locations to CoreData
        dispatch_queue_t queue = dispatch_queue_create("profile picture downloader", NULL);
        dispatch_async(queue, ^{
            NSLog(@"Adding locations into CoreData.");
            for (NSString *userid in self.locations) {
                NSArray *locations = [self.locations objectForKey:userid];
                
                // Add locations into Core Data
                FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                for (NSDictionary<FBGraphPlace> *checkinInfo in locations) {
//                    NSLog(@"Checkininfo: %@", checkinInfo);
                    [Checkin checkinWithFacebookInfo:checkinInfo forUser:[self.users objectForKey:userid] inManagedObjectContext:appDelegate.managedObjectContext];
                    
                    // NOTE: save coredata here to see the errors immediately
                }
                
                if (locations.count > 0) {
                    // Save the context.
                    NSLog(@"Saving locations for user %@", [[self.users objectForKey:userid] valueForKey:@"name"]);
                    FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                    NSError *error = nil;
                    if (![appDelegate.managedObjectContext save:&error]) {
                        /*
                         Replace this implementation with code to handle the error appropriately.
                         
                         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                         */
                        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                        abort();
                    }
                }
            }
            
            // add location objects to the map
            NSLog(@"Adding locations on the map.");
            [self reloadAnnotationsFromCoreData];
        });
    }
    
    _numberOfRunningRequests = numberOfRunningRequests;
    
}

#pragma mark - Managing the detail item

// TODO: this is threaded, it shouldn't write to ivars!
- (void)requestLocationsForUser:(Friend *)user limit:(NSInteger)limit offset:(NSInteger)offset
{
    if (!self.isFetchingAllowed) return;
    
    FBRequestConnection *connection = [[FBRequestConnection alloc] initWithTimeout:120]; // TODO: review the value
    FBRequest *request = [FBRequest requestForGraphPath:[NSString stringWithFormat:@"%@/locations?limit=%i&offset=%i", user.id, limit, offset]];
    [connection addRequest:request completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        self.numberOfRunningRequests--;
        if (!self.isFetchingAllowed) return;
        
        if (!error && result) {
            NSMutableArray *newLocations = [result objectForKey:@"data"];
            
            // add locations to temporary array before showing them on the map
            NSMutableArray *userLocations = [self.locations objectForKey:user.id];
            if (!userLocations) {
                userLocations = [NSMutableArray array];
            }
            [userLocations addObjectsFromArray:newLocations];
            [self.locations setObject:userLocations forKey:user.id];
            
            self.numberOfLocations += newLocations.count;
            NSLog(@"Harvested %i locations (p=%i) for '%@'", newLocations.count, offset/limit, user.name);
            
            if ([[result objectForKey:@"paging"] objectForKey:@"next"] && newLocations.count > 0) {
                // Go to the next page
                [self requestLocationsForUser:user limit:limit offset:offset+limit];
            }
//            else {
//                // no other locations available
//                NSLog(@"All locations for '%@' have been harvested.", user.name);
//            }
        }
        else {
            // TODO: do something with the error
            NSLog(@"Error during fetching locations: %@", error);
        }
    }];
    [connection start];
    self.numberOfRunningRequests++;
    
}

- (void)startDownloadingLocationsForUsers:(NSArray *)users
{
    // save users
    NSMutableDictionary *usersDictionary = [NSMutableDictionary dictionaryWithCapacity:users.count];
    for (Friend *user in users) {
        [usersDictionary setObject:user forKey:user.id];
    }
    self.users = usersDictionary;
    
    // show loading view
    self.loadingView.hidden = NO;
    [UIView transitionWithView:self.loadingView duration:AnimationDuration options:UIViewAnimationOptionLayoutSubviews animations:^{
        //        self.loadingView.alpha = 1;
        CGRect frame = self.loadingView.frame;
        frame.origin.y += frame.size.height;
        self.loadingView.frame = frame;
    } completion:nil];
    
    // start counting
    self.startTime = [NSDate date];
    NSLog(@"Start time: %@", self.startTime);
    NSLog(@"Paging limit = %i", PAGING_LIMIT);
    
    self.isFetchingAllowed = YES;
    for (Friend *user in users) {
        [self requestLocationsForUser:user limit:PAGING_LIMIT offset:0];
    }
}

//- (void)addLocations:(NSMutableArray *)locations forUser:(Friend *)user
//{
//    for (NSDictionary<FBGraphObject> *checkinInfo in locations) {
//        
//        // adding just one annotation is a little bit faster than doing it in a batch
//        [self.mapView addAnnotation:checkin];
//    }
//}

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
