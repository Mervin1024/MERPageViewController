//
//  MERPageViewController.m
//  MERPageViewController
//
//  Created by mayao's Mac on 2019/5/5.
//

#import "MERPageViewController.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSUInteger, MERPageScrollDirection) {
    MERPageScrollDirectionLeft,
    MERPageScrollDirectionRight,
};

@interface UIViewController (MERPageChildController)

@property (nonatomic, strong) id mer_cacheKey;

- (void)mer_addChildViewController:(UIViewController *)childViewController inView:(UIView *)inView frame:(CGRect)frame;
- (void)mer_removeFromParentViewController;

@end

@implementation UIViewController (MERPageChildController)

static void *kMERUIViewControllerCacheKey = &kMERUIViewControllerCacheKey;

- (void)setMer_cacheKey:(id)mer_cacheKey {
    objc_setAssociatedObject(self, kMERUIViewControllerCacheKey, mer_cacheKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)mer_cacheKey {
    return objc_getAssociatedObject(self, kMERUIViewControllerCacheKey);
}

- (void)mer_addChildViewController:(UIViewController *)childViewController inView:(UIView *)inView frame:(CGRect)frame {
    BOOL contains = [self.childViewControllers containsObject:childViewController];
    if (!contains) {
        /* The addChildViewController: method automatically calls the willMoveToParentViewController: method
         * of the view controller to be added as a child before adding it.
         */
        [self addChildViewController:childViewController];
    }
    childViewController.view.frame = frame;
    if (![inView.subviews containsObject:childViewController.view]) {
        [inView addSubview:childViewController.view];
    }
    if (!contains) {
        [childViewController didMoveToParentViewController:self];
    }
}

- (void)mer_removeFromParentViewController {
    if (!self.parentViewController) {
        return;
    }
    [self willMoveToParentViewController:nil]; // 1
    /* The removeFromParentViewController method automatically calls the didMoveToParentViewController: method
     * of the child view controller after it removes the child.
     */
    [self.view removeFromSuperview]; // 2
    [self removeFromParentViewController]; // 3
}

@end

@interface _MERCache <KeyType, ObjectType> : NSCache

@end

@implementation _MERCache

- (void)setObject:(id)obj forKey:(id)key {
    if ([obj isKindOfClass:UIViewController.class]) {
        [(UIViewController*)obj setMer_cacheKey:key];
    }
    [super setObject:obj forKey:key];
}

@end

@interface _MERQueuingScrollView : UIScrollView

@end

@implementation _MERQueuingScrollView

@end

@interface MERPageViewController () <NSCacheDelegate, UIScrollViewDelegate>
{
    // 用于计算的属性值
    NSInteger _currentPageIndex;
    
    CGFloat _originOffset;          //用于手势拖动scrollView时，判断方向
    NSInteger _guessToIndex;        //用于手势拖动scrollView时，判断要去的页面
    NSInteger _lastSelectedIndex;   //用于记录上次选择的index
    BOOL _firstWillAppear;          //用于界定页面首次WillAppear。
    BOOL _firstDidAppear;           //用于界定页面首次DidAppear。
    BOOL _firstDidLayoutSubViews;   //用于界定页面首次DidLayoutsubviews。
    BOOL _firstWillLayoutSubViews;  //用于界定页面首次WillLayoutsubviews。
    
    BOOL _isSwitchAnimating;        //记录是否正在执行切换伪动画
    NSTimeInterval _animationKey;   //记录执行伪动画的 key，用来过滤多个动画执行时，前几个动画的回调
}

@property (nonatomic, strong) _MERQueuingScrollView *queuingScrollView;
@property (nonatomic, strong) NSMutableArray<NSLayoutConstraint*> *queuingScrollViewConstraints;

@property (nonatomic, strong) UIView *switchAnimationContentView;

/**
 缓存 VC
 */
@property (nonatomic, strong) _MERCache<NSNumber *, UIViewController *> *merCache;
/**
 即将被从列表页面中移出的 VC 集合
 */
@property (nonatomic, strong) NSMutableSet<UIViewController *> *childWillRemove;

@end

@implementation MERPageViewController

#pragma mark ----------------- Lazy -----------------

- (_MERQueuingScrollView *)queuingScrollView {
    if (!_queuingScrollView) {
        _queuingScrollView = [[_MERQueuingScrollView alloc] init];
    }
    return _queuingScrollView;
}

- (UIView *)switchAnimationContentView {
    if (!_switchAnimationContentView) {
        _switchAnimationContentView = [[UIView alloc] init];
        _switchAnimationContentView.backgroundColor = [UIColor clearColor];
        _switchAnimationContentView.userInteractionEnabled = NO;
    }
    return _switchAnimationContentView;
}

- (_MERCache<NSNumber *, UIViewController *> *)merCache {
    if (!_merCache) {
        _merCache = [[_MERCache alloc] init];
        _merCache.countLimit = 3;
    }
    return _merCache;
}

- (NSMutableSet<UIViewController *> *)childWillRemove {
    if (!_childWillRemove) {
        _childWillRemove = [NSMutableSet set];
    }
    return _childWillRemove;
}

#pragma mark ----------------- Initialize -----------------

- (instancetype)init {
    self = [super init];
    if (self) {
        [self initVariables];
    }
    return self;
}

- (void)initVariables {
    self.contentInsets = UIEdgeInsetsZero;
    
    _currentPageIndex = 0;
    _originOffset = 0.0f;
    _guessToIndex = -1;
    _lastSelectedIndex = 0;
    _firstWillAppear = YES;
    _firstDidAppear = YES;
    _firstDidLayoutSubViews = YES;
    _firstWillLayoutSubViews = YES;
}

#pragma mark ----------------- View lifecycle -----------------

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.merCache.delegate = self;
    
    [self configureScrollView];
    [self configureAnimationContentView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UIViewController *currentVC = [self controllerAtIndex:_currentPageIndex];
    if (_firstWillAppear) {
        _firstWillAppear = NO;
        [self pageViewControllerWillShowFromIndex:_lastSelectedIndex toIndex:_currentPageIndex animated:NO];
        if ([self.delegate respondsToSelector:@selector(mer_pageViewController:willSwitchControllerFrom:toViewController:animated:)]) {
            UIViewController *lastVC = _lastSelectedIndex==_currentPageIndex ? currentVC : [self controllerAtIndex:_lastSelectedIndex];
            [self.delegate mer_pageViewController:self
                         willSwitchControllerFrom:lastVC
                                 toViewController:currentVC
                                         animated:NO];
        }
    }
    // 必须与 -endAppearanceTransition 成对出现
    [currentVC beginAppearanceTransition:YES animated:animated];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (_firstWillLayoutSubViews) {
        _firstWillLayoutSubViews = NO;
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (_firstDidLayoutSubViews) {
        _firstDidLayoutSubViews = NO;
        // fix bug: 当使用 UINavigationController 来 push 一个包含 UIScrollView 的 UIViewController 时，可能滚动到负偏移量
        if (self.navigationController) {
            if (self.navigationController.viewControllers.lastObject == self) {
                self.queuingScrollView.contentOffset = CGPointZero;
                self.queuingScrollView.contentInset = UIEdgeInsetsZero;
            }
        }
        // fix iOS7 crash : scrollView setContentOffset 将触发 layout subviews methods. 更新 scrollView 的方法使用 GCD 放到下一次 runloop
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateScrollViewLayoutIfNeeded];
            [self updateScrollViewDisplayIndexIfNeeded];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateScrollViewLayoutIfNeeded];
        });
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIViewController *currentVC = [self controllerAtIndex:_currentPageIndex];
    if (_firstDidAppear) {
        _firstDidAppear = NO;
        [self pageViewControllerDidShowFromIndex:_lastSelectedIndex toIndex:_currentPageIndex animated:NO];
        if ([self.delegate respondsToSelector:@selector(mer_pageViewController:didSwitchControllerFrom:toViewController:animated:)]) {
            UIViewController *lastVC = _lastSelectedIndex==_currentPageIndex ? currentVC : [self controllerAtIndex:_lastSelectedIndex];
            [self.delegate mer_pageViewController:self
                          didSwitchControllerFrom:lastVC
                                 toViewController:currentVC
                                         animated:NO];
        }
    }
    [currentVC endAppearanceTransition];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[self controllerAtIndex:_currentPageIndex] beginAppearanceTransition:NO animated:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[self controllerAtIndex:_currentPageIndex] endAppearanceTransition];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.merCache removeAllObjects];
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    return NO;
}

#pragma mark ----------------- UI -----------------

- (void)configureScrollView {
    self.queuingScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.queuingScrollView.delegate = self;
    self.queuingScrollView.showsHorizontalScrollIndicator = NO;
    self.queuingScrollView.showsVerticalScrollIndicator = NO;
    self.queuingScrollView.pagingEnabled = YES;
    self.queuingScrollView.backgroundColor = [UIColor clearColor];
    self.queuingScrollView.scrollsToTop = NO;
    
    [self.view addSubview:self.queuingScrollView];
    // AutoLayout
    NSMutableArray<NSLayoutConstraint*> *constraints = [NSMutableArray arrayWithCapacity:4];
    [constraints addObject:({
        [NSLayoutConstraint constraintWithItem:self.queuingScrollView
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.view
                                     attribute:NSLayoutAttributeLeading
                                    multiplier:1
                                      constant:self.contentInsets.left];
    })];
    [constraints addObject:({
        [NSLayoutConstraint constraintWithItem:self.queuingScrollView
                                     attribute:NSLayoutAttributeTrailing
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.view
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1
                                      constant:self.contentInsets.right];
    })];
    [constraints addObject:({
        [NSLayoutConstraint constraintWithItem:self.queuingScrollView
                                     attribute:NSLayoutAttributeTop
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.topLayoutGuide
                                     attribute:NSLayoutAttributeBottom
                                    multiplier:1
                                      constant:self.contentInsets.top];
    })];
    [constraints addObject:({
        [NSLayoutConstraint constraintWithItem:self.queuingScrollView
                                     attribute:NSLayoutAttributeBottom
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.bottomLayoutGuide
                                     attribute:NSLayoutAttributeTop
                                    multiplier:1
                                      constant:self.contentInsets.bottom];
    })];
    
    [self.view addConstraints:constraints];
    self.queuingScrollViewConstraints = constraints;
}

- (void)configureAnimationContentView {
    self.switchAnimationContentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.switchAnimationContentView];
    // AutoLayout
    NSMutableArray<NSLayoutConstraint*> *constraints = [NSMutableArray arrayWithCapacity:4];
    [constraints addObject:({
        [NSLayoutConstraint constraintWithItem:self.switchAnimationContentView
                                     attribute:NSLayoutAttributeCenterX
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.queuingScrollView
                                     attribute:NSLayoutAttributeCenterX
                                    multiplier:1
                                      constant:0];
    })];
    [constraints addObject:({
        [NSLayoutConstraint constraintWithItem:self.switchAnimationContentView
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.queuingScrollView
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1
                                      constant:0];
    })];
    [constraints addObject:({
        [NSLayoutConstraint constraintWithItem:self.switchAnimationContentView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.queuingScrollView
                                     attribute:NSLayoutAttributeWidth
                                    multiplier:1
                                      constant:0];
    })];
    [constraints addObject:({
        [NSLayoutConstraint constraintWithItem:self.switchAnimationContentView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.queuingScrollView
                                     attribute:NSLayoutAttributeHeight
                                    multiplier:1
                                      constant:0];
    })];
    
    [self.view addConstraints:constraints];
}

- (void)updateScrollViewLayoutIfNeeded {
    if (self.queuingScrollView.frame.size.width > 0) {
        CGFloat widht = self.pageCount * self.queuingScrollView.frame.size.width;
        CGFloat height = self.queuingScrollView.frame.size.height;
        if (widht != self.queuingScrollView.contentSize.width || height != self.queuingScrollView.contentSize.height) {
            self.queuingScrollView.contentSize = CGSizeMake(widht, height);
        }
    }
}

- (void)updateScrollViewDisplayIndexIfNeeded {
    if (self.queuingScrollView.frame.size.width > 0) {
        [self addVisibleViewContorllerForIndex:_currentPageIndex];
        CGPoint newOffset = [self calculateVisibleViewOffsetForIndex:_currentPageIndex];
        if (newOffset.x != self.queuingScrollView.contentOffset.x ||
            newOffset.y != self.queuingScrollView.contentOffset.y) {
            self.queuingScrollView.contentOffset = newOffset;
        }
    }
}

#pragma mark ----------------- Public -----------------

- (void)reloadData {
    _currentPageIndex = MIN(_currentPageIndex, self.pageCount-1);
    UIViewController *currentVC = ({
        UIViewController *vc = nil;
        if ([self.dataSource respondsToSelector:@selector(mer_pageViewController:controllerAtIndex:)]) {
            vc = [self.dataSource mer_pageViewController:self controllerAtIndex:_currentPageIndex];
        }
        vc;
    });
    if (!currentVC) {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@ - controllerAtIndex:] Return value nil is illegal",
         NSStringFromClass([self class])];
    }

    [self.merCache removeAllObjects];
    [self.merCache setObject:currentVC forKey:@(_currentPageIndex)];

    [self.childWillRemove enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj mer_removeFromParentViewController];
    }];
    [self.childWillRemove removeAllObjects];
    
    [currentVC beginAppearanceTransition:YES animated:NO];
    [self updateScrollViewLayoutIfNeeded];
    [self updateScrollViewDisplayIndexIfNeeded];
    [currentVC endAppearanceTransition];
}

/**
 通过代码直接更改当前显示 VC，区别于手部拖动更改 VC

 采用模拟滚动动画的形式做切换，并没有使用 UIScrollView 的 setContentOffset 动画
 由于不相邻的视图通过 contentOffset 动画滚动，无法做到两个 view 贴合无缝滚动，会导致 scroll 过程中所有的 VC 都会被遍历一遍
 
 模拟动画将两个 view 放到视图顶端，做切换动画，完成后放回原位置
 
 @param index 目标索引
 @param animated 是否动画形式切换
 */
- (void)showPageAtIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= self.pageCount) {
        return;
    }
    
    NSInteger oldSelectedIndex = _lastSelectedIndex;
    NSInteger lastSelectedIndex = _lastSelectedIndex = _currentPageIndex;
    NSInteger currentPageIndex = _currentPageIndex = index;
    
    // 判断 scrollView 是否初始化成功并 displayed 完成
    if (self.queuingScrollView.frame.size.width <= 0 || self.queuingScrollView.contentSize.width <= 0) return;
    
    // 滚动执行之前的处理
    dispatch_block_t scrollBeforeAnimation = ^{
        self->_isSwitchAnimating = YES;
        self.queuingScrollView.userInteractionEnabled = NO;
        
        // 添加对应的 VC 到 scrollView 上，并通知代理
        [self pageViewControllerWillShowFromIndex:lastSelectedIndex toIndex:currentPageIndex animated:animated];
        if ([self.delegate respondsToSelector:@selector(mer_pageViewController:willSwitchControllerFrom:toViewController:animated:)]) {
            [self.delegate mer_pageViewController:self
                         willSwitchControllerFrom:[self controllerAtIndex:lastSelectedIndex]
                                 toViewController:[self controllerAtIndex:currentPageIndex]
                                         animated:animated];
        }
        [self addVisibleViewContorllerForIndex:index];

        [[self controllerAtIndex:currentPageIndex] beginAppearanceTransition:YES animated:animated];
        if (currentPageIndex != lastSelectedIndex) {
            [[self controllerAtIndex:lastSelectedIndex] beginAppearanceTransition:NO animated:animated];
        }
    };
    
    // 滚动动画执行完成时的处理
    // 如果不采用动画形式，将直接调用该 block
    dispatch_block_t scrollAnimationCompleted = ^{
        [self.queuingScrollView setContentOffset:[self calculateVisibleViewOffsetForIndex:currentPageIndex] animated:NO];
    };

    // 滚动执行结束的处理 block
    dispatch_block_t scrollAfterAnimation = ^{
        self->_isSwitchAnimating = NO;
        self.queuingScrollView.userInteractionEnabled = YES;
        
        [[self controllerAtIndex:currentPageIndex] endAppearanceTransition];
        if (currentPageIndex != lastSelectedIndex) {
            [[self controllerAtIndex:lastSelectedIndex] endAppearanceTransition];
        }
        
        // 通知结束代理，并清掉不显示的 VC
        [self pageViewControllerDidShowFromIndex:lastSelectedIndex toIndex:currentPageIndex animated:animated];
        if ([self.delegate respondsToSelector:@selector(mer_pageViewController:didSwitchControllerFrom:toViewController:animated:)]) {
            [self.delegate mer_pageViewController:self
                          didSwitchControllerFrom:[self controllerAtIndex:lastSelectedIndex]
                                 toViewController:[self controllerAtIndex:currentPageIndex]
                                         animated:animated];
        }
        [self removeOtherChildVC];
    };
    
    /**
     执行切换流程
     */
    
    scrollBeforeAnimation();
    if (!animated || lastSelectedIndex == currentPageIndex) {
        // 关闭动画或跳转当前页
        scrollAnimationCompleted();
        scrollAfterAnimation();
    } else {
        // 跳转其他页面，模拟动画
        
        // variables
        CGSize pageSize = self.queuingScrollView.frame.size;
        MERPageScrollDirection direction = lastSelectedIndex < currentPageIndex ? MERPageScrollDirectionRight : MERPageScrollDirectionLeft;
        UIViewController *lastVC = [self controllerAtIndex:lastSelectedIndex];
        UIViewController *currentVC = [self controllerAtIndex:currentPageIndex];

        NSTimeInterval duration = 0.3;
        
        // 取消之前的动画
        [self.switchAnimationContentView.layer removeAllAnimations];
        [lastVC.view.layer removeAllAnimations];
        [currentVC.view.layer removeAllAnimations];
        
        // 将不用于此次动画的 view 放置回 scrollView 的原位
        if (oldSelectedIndex != lastSelectedIndex || oldSelectedIndex != currentPageIndex) {
            UIViewController *oldSelectedVC = [self controllerAtIndex:oldSelectedIndex];
            [oldSelectedVC.view.layer removeAllAnimations];
            [self moveChildController:oldSelectedVC backToOriginPositionIfNeeded:oldSelectedIndex];
        }

        // 记录当前动画 key
        NSTimeInterval currentKey = [NSDate timeIntervalSinceReferenceDate];
        _animationKey = currentKey;
        
        // 计算动画需要的坐标
        CGPoint lastViewStartOrigin = CGPointZero;
        CGPoint currentViewStartOrigin = ({
            CGPoint origin = lastViewStartOrigin;
            if (direction == MERPageScrollDirectionRight) {
                origin.x += pageSize.width;
            } else {
                origin.x -= pageSize.width;
            }
            origin;
        });
        
        CGPoint lastViewAnimateToOrigin = ({
            CGPoint origin = lastViewStartOrigin;
            if (direction == MERPageScrollDirectionRight) {
                origin.x -= pageSize.width;
            } else {
                origin.x += pageSize.width;
            }
            origin;
        });
        CGPoint currentViewAnimateToOrigin = lastViewStartOrigin;
            
        [self.switchAnimationContentView addSubview:lastVC.view];
        [self.switchAnimationContentView addSubview:currentVC.view];
        lastVC.view.frame = CGRectMake(lastViewStartOrigin.x, lastViewStartOrigin.y, pageSize.width, pageSize.height);
        currentVC.view.frame = CGRectMake(currentViewStartOrigin.x, currentViewStartOrigin.y, pageSize.width, pageSize.height);;
        [UIView animateWithDuration:duration delay:0 usingSpringWithDamping:1 initialSpringVelocity:3 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            lastVC.view.frame = CGRectMake(lastViewAnimateToOrigin.x, lastViewAnimateToOrigin.y, pageSize.width, pageSize.height);
            currentVC.view.frame = CGRectMake(currentViewAnimateToOrigin.x, currentViewAnimateToOrigin.y, pageSize.width, pageSize.height);;
        } completion:^(BOOL finished) {
            // 被打断的动画不执行以下操作
            if (self->_animationKey == currentKey) {
                [self moveChildController:currentVC backToOriginPositionIfNeeded:currentPageIndex];
                [self moveChildController:lastVC backToOriginPositionIfNeeded:lastSelectedIndex];
                scrollAnimationCompleted();
                scrollAfterAnimation();
            }
        }];
    }
}

- (void)setPageBounces:(BOOL)pageBounces {
    self.queuingScrollView.bounces = pageBounces;
}

- (BOOL)pageBounces {
    return self.queuingScrollView.bounces;
}

- (void)setPageScrollEnable:(BOOL)pageScrollEnable {
    self.queuingScrollView.scrollEnabled = pageScrollEnable;
}

- (BOOL)pageScrollEnable {
    return self.queuingScrollView.scrollEnabled;
}

- (BOOL)currentIndex {
    return _currentPageIndex;
}

- (UIViewController *)currentViewController {
    return [self controllerAtIndex:self.currentIndex];
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets {
    if (UIEdgeInsetsEqualToEdgeInsets(_contentInsets, contentInsets)) return;
    _contentInsets = contentInsets;
    [self.queuingScrollViewConstraints enumerateObjectsUsingBlock:^(NSLayoutConstraint * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.firstAttribute == NSLayoutAttributeLeading) {
            obj.constant = contentInsets.left;
        } else if (obj.firstAttribute == NSLayoutAttributeTrailing) {
            obj.constant = contentInsets.right;
        } else if (obj.firstAttribute == NSLayoutAttributeTop) {
            obj.constant = contentInsets.top;
        } else if (obj.firstAttribute == NSLayoutAttributeBottom) {
            obj.constant = contentInsets.bottom;
        }
    }];
    [self.queuingScrollView layoutIfNeeded];
}

#pragma mark ----------------- Getter -----------------

- (UIViewController *)controllerAtIndex:(NSInteger)index {
    if (index >= self.pageCount || index < 0) return nil;
    
    UIViewController *controller = [self.merCache objectForKey:@(index)];
    if (controller) return controller;
    
    if ([self.dataSource respondsToSelector:@selector(mer_pageViewController:controllerAtIndex:)]) {
        return [self.dataSource mer_pageViewController:self controllerAtIndex:index];
    }
    return nil;
}

- (NSInteger)pageCount {
    if ([self.dataSource respondsToSelector:@selector(numberOfControllersInPageViewController:)]) {
        return [self.dataSource numberOfControllersInPageViewController:self];
    }
    return 0;
}

#pragma mark ----------------- Helper -----------------

- (NSInteger)calculateIndexFromScrollViewOffsetX:(CGFloat)offsetX {
    NSInteger startIndex = offsetX / self.queuingScrollView.frame.size.width;
    return MAX(0, startIndex);
}

- (CGPoint)calculateVisibleViewOffsetForIndex:(NSInteger)index {
    CGFloat viewWidth = self.queuingScrollView.frame.size.width;
    CGFloat maxWidth = self.queuingScrollView.contentSize.width;
    CGFloat offsetX = index * viewWidth;
    
    if (maxWidth > 0) {
        offsetX = MIN(offsetX, maxWidth - viewWidth);
    }
    offsetX = MAX(0, offsetX);
    
    return CGPointMake(offsetX, 0);
}

- (CGRect)calculateVisibleViewControllerFrameForIndex:(NSInteger)index {
    CGFloat offsetX = [self calculateVisibleViewOffsetForIndex:index].x;
    return CGRectMake(offsetX, 0, self.queuingScrollView.frame.size.width, self.queuingScrollView.frame.size.height);
}

- (void)addVisibleViewContorllerForIndex:(NSInteger)index {
    if (index < 0 || index >= self.pageCount) return;

    UIViewController *vc = [self controllerAtIndex:index];
    if (!vc) return;
    
    CGRect childViewFrame = [self calculateVisibleViewControllerFrameForIndex:index];
    [self mer_addChildViewController:vc inView:self.queuingScrollView frame:childViewFrame];
    [self.merCache setObject:vc forKey:@(index)];
}

- (void)removeOtherChildVC {
    UIViewController *currentVC = [self controllerAtIndex:_currentPageIndex];
    
    // 不要把当前页面移出
    if ([self.childWillRemove containsObject:currentVC]) {
        [self.childWillRemove removeObject:currentVC];
        [self.merCache setObject:currentVC forKey:@(_currentPageIndex)];
    }
    
    // 从父 View 移出其他所有的 VC
    [self.childWillRemove enumerateObjectsUsingBlock:^(UIViewController * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj mer_removeFromParentViewController];
    }];
    [self.childWillRemove removeAllObjects];
}

- (void)moveChildController:(UIViewController *)viewController backToOriginPositionIfNeeded:(NSInteger)index {
    if (index < 0 || index >= self.pageCount) return;
    if (!viewController) return;
    if (!viewController.parentViewController) return;
    CGPoint originPosition = [self calculateVisibleViewOffsetForIndex:index];
    if (viewController.view.frame.origin.x != originPosition.x || ![self.queuingScrollView.subviews containsObject:viewController.view]) {
        viewController.view.frame = ({
            CGRect frame = viewController.view.frame;
            frame.origin = originPosition;
            frame;
        });
        [self.queuingScrollView addSubview:viewController.view];
    }
    
}


/**
 根据位置，重新更新当前显示 VC，在切换结束时调用
 */
- (void)updatePageViewAfterTragging:(UIScrollView *)scrollView {
    if (_isSwitchAnimating) return;
    
    NSInteger newIndex = [self calculateIndexFromScrollViewOffsetX:scrollView.contentOffset.x];
    
    NSInteger oldIndex = _currentPageIndex;
    _currentPageIndex = newIndex;
    
    if (newIndex == oldIndex && newIndex == MAX(0, MIN(_guessToIndex, self.pageCount-1))) {
        // 在边界位置向边界外拖动，不做操作
        return;
    }
    
    UIViewController *oldIndexVC = [self controllerAtIndex:oldIndex];
    UIViewController *newIndexVC = [self controllerAtIndex:newIndex];
    UIViewController *guessToIndexVC = [self controllerAtIndex:_guessToIndex];
    //最终确定的位置与开始位置相同时，需要重新显示开始位置的视图，以及 dismiss 最近一次猜测的位置的视图。
    if (newIndex == oldIndex) {
        if (_guessToIndex >= 0 && _guessToIndex < self.pageCount) {
            [oldIndexVC beginAppearanceTransition:YES animated:YES];
            [oldIndexVC endAppearanceTransition];
            [guessToIndexVC beginAppearanceTransition:NO animated:YES];
            [guessToIndexVC endAppearanceTransition];
        }
    } else {
        [oldIndexVC endAppearanceTransition];
        [newIndexVC endAppearanceTransition];
    }
    
    //归位，用于计算比较
    _originOffset = scrollView.contentOffset.x;
    _guessToIndex = _currentPageIndex;
    
    [self pageViewControllerDidTransitionFromIndex:oldIndex toIndex:newIndex];
    if ([self.delegate respondsToSelector:@selector(mer_pageViewController:didTransitionFrom:toViewController:)]) {
        [self.delegate mer_pageViewController:self didTransitionFrom:oldIndexVC toViewController:newIndexVC];
    }
    
    [self removeOtherChildVC];
}

#pragma mark ----------------- UIScrollViewDelegate -----------------

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (_isSwitchAnimating) return;
    
    CGFloat offsetX = scrollView.contentOffset.x;
    CGFloat widht = scrollView.frame.size.width;
    NSInteger lastGuessIndex = _guessToIndex < 0 ? _currentPageIndex : _guessToIndex;
    
    if (_originOffset < offsetX) {
        // 向右滑，向左侧 view 切换
        _guessToIndex = ceil(offsetX/widht);
    } else if (_originOffset > offsetX) {
        _guessToIndex = floor(offsetX/widht);
    } else {}
    
    NSInteger pageCount = self.pageCount;
    // 过滤掉非法跳转（目标相同或越界）
    if (lastGuessIndex == _guessToIndex) return;
    if (_guessToIndex < 0 || _guessToIndex >= pageCount) return;
    
    /**
     这里只处理两种情况
     1. 非交互切换(irreciprocalSwitch)的开启，_guessToIndex 不同于 _currentPageIndex，且 isDecelerating 为 false
     2. 交互式切换(interactionSwitch)的开启（松手时刻），isDecelerating 为 true
     */
    BOOL irreciprocalSwitch = _guessToIndex != _currentPageIndex && scrollView.isDecelerating == NO;
    BOOL interactionSwitch = scrollView.isDecelerating == YES;
    if (!irreciprocalSwitch && !interactionSwitch) return;
    
    UIViewController *lastGuessVC = [self controllerAtIndex:lastGuessIndex];
    UIViewController *guessToIndexVC = [self controllerAtIndex:_guessToIndex];
    UIViewController *currentIndexVC = [self controllerAtIndex:_currentPageIndex];

    [self pageViewControllerWillTransitionFromIndex:_currentPageIndex toIndex:_guessToIndex];
    if ([self.delegate respondsToSelector:@selector(mer_pageViewController:willTransitionFrom:toViewController:)]) {
        [self.delegate mer_pageViewController:self
                           willTransitionFrom:currentIndexVC
                             toViewController:guessToIndexVC];
    }
    [self addVisibleViewContorllerForIndex:_guessToIndex];
    
    // 处理 VC 的生命周期
    [guessToIndexVC beginAppearanceTransition:YES animated:YES];
    [lastGuessVC beginAppearanceTransition:NO animated:YES];

    if (lastGuessIndex != _currentPageIndex) {
        [lastGuessVC endAppearanceTransition];
    }
    
}

// 手指拖动后抬起
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
}

// 视图结束滚动
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (!scrollView.isDragging) {
        [self updatePageViewAfterTragging:scrollView];
    }
}

// 开始拖动（需要 scrollViewDidScroll 一定距离和时间后，这里才会被调用）
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (!scrollView.isDecelerating) {
        _originOffset = scrollView.contentOffset.x;
        _guessToIndex = _currentPageIndex;
    }
}

// 手指拖动后抬起，可以重设停止目标。 velocity 单位为 points/millisecond
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    CGFloat offsetX = scrollView.contentOffset.x;
    CGFloat width = scrollView.frame.size.width;

    if (velocity.x > 0) {
        // 手指向左，滚动到右向视图
        if (scrollView.isDecelerating) {
            _originOffset = floor(offsetX/width) * width;
        }
    } else if (velocity.x < 0) {
        // 手指向右，滚动到左向视图
        if (scrollView.isDecelerating) {
            _originOffset = ceil(offsetX/width) * width;
        }
    }
    
    // 手指抬起的时候，刚好不需要任何减速就停留在目标位置，则主动调用刷新 page。
    if ((int)(offsetX * 100) % (int)(width * 100) == 0) {
        [self updatePageViewAfterTragging:scrollView];
    }
    
}

#pragma mark ----------------- NSCacheDelegate -----------------

- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    if (![obj isKindOfClass:UIViewController.class]) return;
    if (![self.childViewControllers containsObject:obj]) return;
    
    UIViewController *vc = (UIViewController *)obj;
    NSNumber *cacheKey = vc.mer_cacheKey;
    NSInteger index = cacheKey?cacheKey.integerValue:NSNotFound;
    // 当 queuingScrollView 处于 isDragging 状态，Tracking 和 Decelerating 状态都是 NO。
    // 判断全部为 NO ，代表着缓存清除不是由连续的页面交互触发的
    if (!self.queuingScrollView.isDragging &&
        !self.queuingScrollView.isTracking &&
        !self.queuingScrollView.isDecelerating) {
        if (_lastSelectedIndex == index || _currentPageIndex == index) {
            [self.childWillRemove addObject:vc];
        }
    } else if (self.queuingScrollView.isDragging) {
        
        NSInteger leftIndex = _guessToIndex - 1;
        NSInteger rightIndex = _guessToIndex + 1;
        if (leftIndex < 0) {
            leftIndex = _guessToIndex;
        }
        if (rightIndex > self.pageCount - 1) {
            rightIndex = _guessToIndex;
        }
        
        if (leftIndex == index || rightIndex == index || _guessToIndex == index) {
            [self.childWillRemove addObject:vc];
        }
    }
    
    if ([self.childWillRemove containsObject:vc]) return;

    [vc mer_removeFromParentViewController];
}

#pragma mark ----------------- Subclass Override -----------------

- (void)pageViewControllerWillTransitionFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex {}
- (void)pageViewControllerDidTransitionFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex {}
- (void)pageViewControllerWillShowFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex animated:(BOOL)animated{}
- (void)pageViewControllerDidShowFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex animated:(BOOL)animated{}


@end
