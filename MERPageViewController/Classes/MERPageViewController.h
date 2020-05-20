//
//  MERPageViewController.h
//  MERPageViewController
//
//  Created by mayao's Mac on 2019/5/5.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MERPageViewControllerDelegate, MERPageViewControllerDataSource;

@interface MERPageViewController : UIViewController

@property (nullable, nonatomic, weak) id <MERPageViewControllerDelegate> delegate;
@property (nullable, nonatomic, weak) id <MERPageViewControllerDataSource> dataSource;

@property (nonatomic, assign) UIEdgeInsets contentInsets;

@property (nonatomic, readonly, assign) NSInteger currentIndex;
@property (nullable, nonatomic, readonly, weak) UIViewController *currentViewController;

/**
 是否支持弹性效果，默认为 YES
 */
@property (nonatomic, assign) BOOL pageBounces;
/**
 页面是否支持滑动切换，默认为 YES。
 */
@property (nonatomic, assign) BOOL pageScrollEnable;

- (void)showPageAtIndex:(NSInteger)index animated:(BOOL)animated completion:(void(^_Nullable)(BOOL finished))completion;

- (void)reloadData;

@end

typedef NS_ENUM(NSUInteger, MERTransitionType) {
    MERTransitionTypeDragging = 0, /// 使用手势拖动方式切换
    MERTransitionTypeSwitch   = 1, /// 使用 -showPageAtIndex:animated: 切换
};

@protocol MERPageViewControllerDelegate <NSObject>

@optional

/// transitionType 切换的方式
/// 切换发起回调
- (void)mer_pageViewController:(MERPageViewController *)pageViewController
            willTransitionFrom:(UIViewController *)previousViewController
              toViewController:(UIViewController *)pendingViewController
                transitionType:(MERTransitionType)transitionType
                      animated:(BOOL)animated;
/// 切换完成回调
- (void)mer_pageViewController:(MERPageViewController *)pageViewController
             didTransitionFrom:(UIViewController *)previousViewController
              toViewController:(UIViewController *)pendingViewController
                transitionType:(MERTransitionType)transitionType
                      animated:(BOOL)animated;
/// scrollView 滑动代理
- (void)mer_pageViewController:(MERPageViewController *)pageViewController
           scrollViewDidScroll:(UIScrollView *)scrollView
                transitionType:(MERTransitionType)transitionType;
@end

@protocol MERPageViewControllerDataSource <NSObject>

- (NSInteger)numberOfControllersInPageViewController:(MERPageViewController *)pageViewController;
- (UIViewController *)mer_pageViewController:(MERPageViewController *)pageViewController controllerAtIndex:(NSInteger)index;

@optional

@end


@interface MERPageViewController ()

// To override，no need to call super
- (void)pageViewControllerWillTransitionFromIndex:(NSInteger)fromIndex
                                          toIndex:(NSInteger)toIndex
                                   transitionType:(MERTransitionType)transitionType
                                         animated:(BOOL)animated;
- (void)pageViewControllerDidTransitionFromIndex:(NSInteger)fromIndex
                                         toIndex:(NSInteger)toIndex
                                  transitionType:(MERTransitionType)transitionType
                                        animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
