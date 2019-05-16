//
//  MERPageViewController.h
//  MERPageViewController
//
//  Created by mayao's Mac on 2019/5/5.
//

#import <UIKit/UIKit.h>

void blockCleanUp(__strong void(^_Nonnull* _Nonnull block)(void));

NS_ASSUME_NONNULL_BEGIN

@protocol MERPageViewControllerDelegate, MERPageViewControllerDataSource;

@interface MERPageViewController : UIViewController

@property (nullable, nonatomic, weak) id <MERPageViewControllerDelegate> delegate;
@property (nullable, nonatomic, weak) id <MERPageViewControllerDataSource> dataSource;

@property (nonatomic, assign) UIEdgeInsets contentInsets;

/**
 是否支持弹性效果，默认为 YES
 */
@property (nonatomic, assign) BOOL pageBounces;
/**
 页面是否支持滑动切换，默认为 YES。
 */
@property (nonatomic, assign) BOOL pageScrollEnable;

- (void)showPageAtIndex:(NSInteger)index animated:(BOOL)animated;

@end

@protocol MERPageViewControllerDelegate <NSObject>

@optional

// 手势滑动触发此处代理
- (void)mer_pageViewController:(MERPageViewController *)pageViewController willTransitionFrom:(UIViewController *)previousViewController toViewController:(UIViewController *)pendingViewController;
- (void)mer_pageViewController:(MERPageViewController *)pageViewController didTransitionFrom:(UIViewController *)previousViewController toViewController:(UIViewController *)pendingViewController;
// 调用 -showPageAtIndex:animated: 触发此处代理
- (void)mer_pageViewController:(MERPageViewController *)pageViewController willSwitchControllerFrom:(UIViewController *)previousViewController toViewController:(UIViewController *)pendingViewController animated:(BOOL)animated;
- (void)mer_pageViewController:(MERPageViewController *)pageViewController didSwitchControllerFrom:(UIViewController *)previousViewController toViewController:(UIViewController *)pendingViewController animated:(BOOL)animated;

@end

@protocol MERPageViewControllerDataSource <NSObject>

- (NSInteger)numberOfControllersInPageViewController:(MERPageViewController *)pageViewController;
- (UIViewController *)mer_pageViewController:(MERPageViewController *)pageViewController controllerAtIndex:(NSInteger)index;

@optional

@end


@interface MERPageViewController ()

// Override，no need to call super

// 当手势切换发起时调用
- (void)pageViewControllerWillTransitionFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex;
// 当手势切换结束时调用
- (void)pageViewControllerDidTransitionFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex;
// 当 -showPageAtIndex:animated: 触发时调用
- (void)pageViewControllerWillShowFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex animated:(BOOL)animated;
// 当 -showPageAtIndex:animated: 完成时调用
- (void)pageViewControllerDidShowFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
