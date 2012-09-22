//
//  CheckinViewController.m
//  FacebookMap
//
//  Created by Tom K on 9/21/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "CheckinViewController.h"
#import "Checkin.h"
#import "Friend.h"
#import "Location.h"
#import <FacebookSDK/FacebookSDK.h>
#import "FileCache.h"

@interface CheckinViewController ()
@property (strong, nonatomic) Checkin *checkin;

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *typeLabel;
@property (weak, nonatomic) IBOutlet UILabel *userInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *placeInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *coordinatesLabel;
@property (weak, nonatomic) IBOutlet UILabel *datetimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;

@property (strong, nonatomic) FileCache *cache;

@end

@implementation CheckinViewController

- (IBAction)dismissPressed:(id)sender {
    [self.delegate dismissCheckinInfo:self];
}


- (FileCache *)cache
{
    if (!_cache) {
        _cache = [[FileCache alloc] init];
        _cache.maxSize = 100;
        _cache.domain = @"thumbnails";
    }
    return  _cache;
}

- (void)configure:(Checkin *)checkin
{
    self.checkin = checkin;
    
    self.typeLabel.text = checkin.type;
    self.userInfoLabel.text = [((Friend *)[checkin.whoHasBeenThere anyObject]) name];
    self.placeInfoLabel.text = [NSString stringWithFormat:@"%@, %@, %@", checkin.location.name, checkin.location.city, checkin.location.country];
    self.coordinatesLabel.text = [NSString stringWithFormat:@"%@, %@", checkin.location.latitude, checkin.location.longitude];
    self.datetimeLabel.text = [checkin.created_time description];

    FBRequest *request = [FBRequest requestForGraphPath:checkin.id];
    [request startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (!error && result) {
//            NSLog(@"checkin info: %@", result);
            self.messageLabel.text = [result objectForKey:@"message"];
            
            if ([result objectForKey:@"images"]) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                    NSString *checkinID = [result objectForKey:@"id"];
                    NSData *imageData = [self.cache dataForKey:checkinID];
                    
                    if (!imageData) {
                        NSURL *url;
                        for (NSDictionary *imageInfo in [result objectForKey:@"images"]) {
                            // TODO: review the condition
                            NSInteger width = [[imageInfo objectForKey:@"width"] integerValue];
                            if (width <= 480) {
                                url = [NSURL URLWithString:[imageInfo objectForKey:@"source"]];
                                break;
                            }
                        }
                        
                        NSLog(@"dowloading image: %@", url.absoluteString);
                        imageData = [NSData dataWithContentsOfURL:url];
                        [self.cache saveData:imageData forKey:checkinID];
                    }
                    
                    UIImage *image = [UIImage imageWithData:imageData];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.imageView.image = image;
                    });
                });
            }
        }
    }];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self configure:self.checkin];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setImageView:nil];
    [self setTypeLabel:nil];
    [self setUserInfoLabel:nil];
    [self setPlaceInfoLabel:nil];
    [self setCoordinatesLabel:nil];
    [self setDatetimeLabel:nil];
    [self setMessageLabel:nil];
    [super viewDidUnload];
}
@end
