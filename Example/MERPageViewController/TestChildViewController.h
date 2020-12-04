//
//  TestChildViewController.h
//  MERPageViewController_Example
//
//  Created by mayao's Mac on 2020/12/1.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

#import <UIKit/UIKit.h>
@import MERPageViewController;

NS_ASSUME_NONNULL_BEGIN

@interface TestChildViewController : UIViewController <MERPageReusable>
@property (nonatomic, assign) NSString *name;
@end

NS_ASSUME_NONNULL_END
