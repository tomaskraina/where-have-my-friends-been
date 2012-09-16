//
//  LogInViewController.m
//  FacebookMap
//
//  Created by Tom Kraina on 14.09.2012.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "LogInViewController.h"
#import "FacebookMapAppDelegate.h"

@implementation LogInViewController

- (IBAction)performLogin
{
    // TODO: spinner maybe?
    
    FacebookMapAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate facebookOpenSessionWithAllowLoginUI:YES];
}

- (void)loginFailed
{
    // cleanup
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

@end
