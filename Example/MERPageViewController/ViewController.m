//
//  ViewController.m
//  MERPageViewController_Example
//
//  Created by mayao's Mac on 2020/12/1.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

#import "ViewController.h"
#import "TestChildViewController.h"
@import MERPageViewController;

@interface ViewController () <MERPageViewControllerDataSource, MERPageViewControllerDelegate>
@property (nonatomic, strong) MERPageViewController *pageViewController;
@property (nonatomic, strong) NSMutableArray<NSString *> *dataArray;
@end

@implementation ViewController
- (NSMutableArray<NSString *> *)dataArray {
    if (!_dataArray) {
        _dataArray = [NSMutableArray arrayWithCapacity:10];
        for (NSInteger i = 0; i < 10; i++) {
            [_dataArray addObject:@(i).description];
        }
    }
    return _dataArray;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.pageViewController = [[MERPageViewController alloc] init];
    self.pageViewController.dataSource = self;
    self.pageViewController.delegate = self;
    [self addChildViewController:self.pageViewController];
    [self.view addSubview:self.pageViewController.view];
    self.pageViewController.view.frame = self.view.bounds;
    self.pageViewController.pageBounces = NO;
    [self.pageViewController registerClass:TestChildViewController.class];
    
    UIButton *touchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    touchButton.titleLabel.font = [UIFont systemFontOfSize:30];
    [touchButton setTitle:@"随机跳转" forState:UIControlStateNormal];
    [touchButton sizeToFit];
    [self.view addSubview:touchButton];
    touchButton.center = CGPointMake(self.view.center.x, self.view.center.y - 100);
    [touchButton addTarget:self action:@selector(touchButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
}

- (void)touchButtonPressed:(id)sender {
    NSInteger currentIndex = self.pageViewController.currentIndex;
    NSInteger targetIndex;
    do {
        targetIndex = arc4random()%(self.dataArray.count);
    } while (currentIndex == targetIndex);
    [self.pageViewController showPageAt:targetIndex animated:YES completion:nil];
}

#pragma mark ----------------- MERPageViewControllerDataSource -----------------
- (NSInteger)numberOfControllersIn:(MERPageViewController *)controller {
    return self.dataArray.count;
}

- (UIViewController *)mer_pageViewController:(MERPageViewController *)controller controllerAt:(NSInteger)index {
    UIViewController *child = [controller dequeueReusableChild:TestChildViewController.class forIndex:index];
    if ([child isKindOfClass:TestChildViewController.class]) {
        [(TestChildViewController *)child setName:self.dataArray[index]];
    }
    return child;
}

#pragma mark ----------------- MERPageViewControllerDelegate -----------------
- (void)mer_pageViewController:(MERPageViewController *)controller willTransitionFrom:(NSInteger)willTransitionFrom to:(NSInteger)to transitionType:(enum TransitionType)transitionType animated:(BOOL)animated {
    
}

- (void)mer_pageViewController:(MERPageViewController *)controller didTransitionFrom:(NSInteger)didTransitionFrom to:(NSInteger)to transitionType:(enum TransitionType)transitionType animated:(BOOL)animated {
    
}

- (void)mer_pageViewController:(MERPageViewController *)controller scrollViewDidScroll:(UIScrollView *)scrollViewDidScroll transitionType:(enum TransitionType)transitionType {
    
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
