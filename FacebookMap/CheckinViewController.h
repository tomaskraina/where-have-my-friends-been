//
//  CheckinViewController.h
//  FacebookMap
//
//  Created by Tom K on 9/21/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import <UIKit/UIKit.h>
@class Checkin;
@class CheckinViewController;

@protocol CheckinViewControllerDelegate <NSObject>
- (void)dismissCheckinInfo:(CheckinViewController *)sender;
@end

@interface CheckinViewController : UIViewController

@property (nonatomic, strong) id<CheckinViewControllerDelegate> delegate;

- (void)configure:(Checkin *)checkin;

@end
