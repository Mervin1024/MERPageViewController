//
//  MERViewController.m
//  MERPageViewController
//
//  Created by Mervin1024 on 05/05/2019.
//  Copyright (c) 2019 Mervin1024. All rights reserved.
//

#import "MERViewController.h"
#import <MERPageViewController/MERPageViewController.h>
#import "MERTestChildViewController.h"

@interface MERViewController () <MERPageViewControllerDataSource, MERPageViewControllerDelegate>
@property (nonatomic, strong) MERPageViewController *pageViewController;
@property (nonatomic, strong) NSMutableArray<UIViewController *> *pageControllers;
@end

@implementation MERViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.pageViewController = [[MERPageViewController alloc] init];
    self.pageViewController.dataSource = self;
    self.pageViewController.delegate = self;
    [self addChildViewController:self.pageViewController];
    [self.view addSubview:self.pageViewController.view];
    self.pageViewController.view.frame = [UIScreen mainScreen].bounds;
    
//    self.pageViewController.pageBounces = NO;
    
    self.pageControllers = [NSMutableArray arrayWithCapacity:10];
    for (int i = 0; i < 10; i++) {
        MERTestChildViewController *controller = [[MERTestChildViewController alloc] init];
        controller.index = i;
        [self.pageControllers addObject:controller];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark ----------------- MERPageViewControllerDataSource -----------------

- (nonnull UIViewController *)mer_pageViewController:(nonnull MERPageViewController *)pageViewController controllerAtIndex:(NSInteger)index {
    return [self.pageControllers objectAtIndex:index];
}

- (NSInteger)numberOfControllersInPageViewController:(nonnull MERPageViewController *)pageViewController {
    return self.pageControllers.count;
}


#pragma mark ----------------- MERPageViewControllerDelegate -----------------

- (void)mer_pageViewController:(MERPageViewController *)pageViewController willTransitionFrom:(UIViewController *)previousViewController toViewController:(UIViewController *)pendingViewController {
    NSLog(@"will Transition From : %@ ,To : %@", @([self.pageControllers indexOfObject:previousViewController]), @([self.pageControllers indexOfObject:pendingViewController]));
}

- (void)mer_pageViewController:(MERPageViewController *)pageViewController didTransitionFrom:(UIViewController *)previousViewController toViewController:(UIViewController *)pendingViewController {
    NSLog(@"Did Transition From : %@ ,To : %@", @([self.pageControllers indexOfObject:previousViewController]), @([self.pageControllers indexOfObject:pendingViewController]));
}

- (void)mer_pageViewController:(MERPageViewController *)pageViewController willSwitchControllerFrom:(UIViewController *)previousViewController toViewController:(UIViewController *)pendingViewController animated:(BOOL)animated {
    NSLog(@"will Swtich From : %@ ,To : %@", @([self.pageControllers indexOfObject:previousViewController]), @([self.pageControllers indexOfObject:pendingViewController]));
}

- (void)mer_pageViewController:(MERPageViewController *)pageViewController didSwitchControllerFrom:(UIViewController *)previousViewController toViewController:(UIViewController *)pendingViewController animated:(BOOL)animated {
    NSLog(@"Did Switch From : %@ ,To : %@", @([self.pageControllers indexOfObject:previousViewController]), @([self.pageControllers indexOfObject:pendingViewController]));
}

@end
