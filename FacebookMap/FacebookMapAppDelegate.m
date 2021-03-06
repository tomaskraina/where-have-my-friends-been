//
//  FacebookMapAppDelegate.m
//  FacebookMap
//
//  Created by Tom Kraina on 14.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "FacebookMapAppDelegate.h"
#import "FriendsTableViewController.h"
#import <FacebookSDK/FacebookSDK.h>

NSString *const FBSessionStateChangedNotification = @"com.tomkraina.FacebookMap:FBSessionStateChangedNotification";

@implementation FacebookMapAppDelegate

@synthesize window = _window;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;

/*
 * If we have a valid session at the time of openURL call, we handle
 * Facebook transitions by passing the url argument to handleOpenURL
 */
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation 
{
    // attempt to extract a token from the url
    return [FBSession.activeSession handleOpenURL:url]; 
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
//    [self deleteCoreData];
    
    // Override point for customization after application launch.
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
    splitViewController.delegate = (id)navigationController.topViewController;
    
    // don't show masterViewController with a swipe gesture (iOS >= 5.1)
    if ([splitViewController respondsToSelector:@selector(setPresentsWithGesture:)]) splitViewController.presentsWithGesture = NO;


    UINavigationController *masterNavigationController = [splitViewController.viewControllers objectAtIndex:0];
    FriendsTableViewController *controller = (FriendsTableViewController *)masterNavigationController.topViewController;
    controller.managedObjectContext = self.managedObjectContext;
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    
    // this means the user switched back to this app without completing 
    // a login in Safari/Facebook App
    if (FBSession.activeSession.state == FBSessionStateCreatedOpening) {    
        [FBSession.activeSession close]; // so we close our session and start over  
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
    
    // close facebook session
    [FBSession.activeSession close];
}

- (void)saveContext
{
    NSLog(@"Saving context...");
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil)
    {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
        {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

- (void)deleteCoreData
{
    NSLog(@"Deleting CoreData objects...");
    
    [self.managedObjectContext performBlockAndWait:^{
        NSArray *entities = [NSArray arrayWithObjects:@"Friend", @"Checkin", @"Location", nil];
        for (NSString *entity in entities) {
            NSFetchRequest * request = [[NSFetchRequest alloc] initWithEntityName:entity];
            request.includesPropertyValues = NO; //only fetch the managedObjectID
            request.includesSubentities = NO;
            
            NSError *error;
            NSArray *allObjects = [self.managedObjectContext executeFetchRequest:request error:&error];
            if (!allObjects || error) {
                NSLog(@"Error: Could't load data to delete: %@", error.debugDescription);
                abort();
            }
            for (NSManagedObject *object in allObjects) {
                [self.managedObjectContext deleteObject:object];
            }
        }
        
        // Save changes
        NSLog(@"Saving context...");
        NSError *saveError;
        if (![self.managedObjectContext save:&saveError]) {
            NSLog(@"Error with deleting friends: %@", saveError.debugDescription);
            abort();
        }
        
        NSLog(@"Objects deleted.");
    }];
}

#pragma mark - Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil)
    {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        __managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
        __managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    }
    return __managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil)
    {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"FacebookMap" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil)
    {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"FacebookMap.sqlite"];
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error])
    {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter: 
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        
        // Try to delete current store
        [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
        
        abort();
    }    
    
    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - Facebook

- (void)facebookSessionStateChanged:(FBSession *)session state:(FBSessionState)state error:(NSError *)error
{
    switch (state) {
        case FBSessionStateOpen:
            if (!error) {
                // We have a valid session
                NSLog(@"Facebook: User session found");
            }
            break;
        case FBSessionStateClosed:
        case FBSessionStateClosedLoginFailed:
            [FBSession.activeSession closeAndClearTokenInformation];
            break;
        default:
            break;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FBSessionStateChangedNotification object:session];
    
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Error"
                                  message:error.localizedDescription
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
    }    
}

- (void)facebookOpenSessionWithAllowLoginUI:(BOOL)allowLoginUI;
{
    NSArray *permissions = [NSArray arrayWithObjects:@"friends_status", @"friends_photos", @"friends_hometown", @"friends_location",  nil];
    [FBSession openActiveSessionWithPermissions:permissions allowLoginUI:allowLoginUI completionHandler:
     ^(FBSession *session, FBSessionState state, NSError *error) {
         [self facebookSessionStateChanged:session state:state error:error];
     }];    
}

- (void) facebookCloseSession {
    [FBSession.activeSession closeAndClearTokenInformation];
}

@end
