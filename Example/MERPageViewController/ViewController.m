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
@property (nonatomic, strong) NSMutableArray<UIViewController *> *pageControllers;
@end

@implementation ViewController
- (NSMutableArray<UIViewController *> *)pageControllers {
    if (!_pageControllers) {
        _pageControllers = [NSMutableArray arrayWithCapacity:10];
        for (int i = 0; i < 10; i++) {
            TestChildViewController *controller = [[TestChildViewController alloc] init];
            controller.index = i;
            [_pageControllers addObject:controller];
        }
    }
    return _pageControllers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.pageViewController = [[MERPageViewController alloc] init];
    self.pageViewController.dataSource = self;
    self.pageViewController.delegate = self;
    [self addChildViewController:self.pageViewController];
    [self.view addSubview:self.pageViewController.view];
    self.pageViewController.view.frame = [UIScreen mainScreen].bounds;
    
    self.pageViewController.pageBounces = NO;
    
    
    UIButton *touchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    touchButton.titleLabel.font = [UIFont systemFontOfSize:30];
    [touchButton setTitle:@"随机跳转" forState:UIControlStateNormal];
    [touchButton sizeToFit];
    [self.view addSubview:touchButton];
    touchButton.center = CGPointMake(self.view.center.x, self.view.center.y - 100);
    [touchButton addTarget:self action:@selector(touchButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *reloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    reloadButton.titleLabel.font = [UIFont systemFontOfSize:30];
    [reloadButton setTitle:@"刷新数据" forState:UIControlStateNormal];
    [reloadButton sizeToFit];
    [self.view addSubview:reloadButton];
    reloadButton.center = CGPointMake(self.view.center.x, self.view.center.y + 100);
    [reloadButton addTarget:self action:@selector(reloadButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

}

- (void)touchButtonPressed:(id)sender {
    NSInteger currentIndex = self.pageViewController.currentIndex;
    NSInteger targetIndex;
    do {
        targetIndex = arc4random()%(self.pageControllers.count);
    } while (currentIndex == targetIndex);
    [self.pageViewController showPageAt:targetIndex animated:YES completion:nil];
}

- (void)reloadButtonPressed:(id)sender {
    self.pageControllers = nil;
    self.pageViewController.contentInsets = UIEdgeInsetsMake(arc4random()%100, 0, 0, 0);
    [self.pageViewController reloadData];
}

#pragma mark ----------------- MERPageViewControllerDataSource -----------------
- (NSInteger)numberOfControllersIn:(MERPageViewController *)controller {
    return self.pageControllers.count;
}

- (UIViewController *)mer_pageViewController:(MERPageViewController *)controller controllerAt:(NSInteger)index {
    return [self.pageControllers objectAtIndex:index];
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
