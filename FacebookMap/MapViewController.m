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

@interface MapViewController () <MKMapViewDelegate>
@property (strong, nonatomic) NSMutableDictionary *locations;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation MapViewController

@synthesize detailItem = _detailItem;
@synthesize mapView = _mapView;
@synthesize masterPopoverController = _masterPopoverController;
@synthesize locations = _locations;

#pragma mark - Managing the detail item

- (void)addLocations:(NSArray *)locations forUser:(NSDictionary<FBGraphUser> *)user;
{
    // TODO: prevent duplicates
    [self.locations setObject:locations forKey:user.id];
    
    for (id<FBGraphObject> object in locations) {
        NSMutableDictionary<FBGraphPlace> *place = [object objectForKey:@"place"];
        NSMutableDictionary<FBGraphLocation> *location = (NSMutableDictionary<FBGraphLocation> *)place.location;
        
        // skip this one if latitude or longitude is missing
        if (![location respondsToSelector:@selector(latitude)] || ![location respondsToSelector:@selector(longitude)]) continue;
        
        CLLocationCoordinate2D coordinates = CLLocationCoordinate2DMake([location.latitude doubleValue], [location.longitude doubleValue]);
        PlaceMapAnnotation *annotation = [[PlaceMapAnnotation alloc] initWithTitle:user.name subtitle:place.name coordinate:coordinates info:nil];

        // adding just one annotation is a little bit faster than doing it in a batch
        [self.mapView addAnnotation:annotation];
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
    } else {
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

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Friends", @"Friends");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    static NSString *Identifier = @"Place Annotation";
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:Identifier];
    if (!annotationView) {
        annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:Identifier];
        annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        annotationView.canShowCallout = YES;
    }
    
    return annotationView;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    
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
