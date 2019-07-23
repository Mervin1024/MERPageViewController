# MERPageViewController

[![Version](https://img.shields.io/cocoapods/v/MERPageViewController.svg?style=flat)](https://cocoapods.org/pods/MERPageViewController)
[![License](https://img.shields.io/cocoapods/l/MERPageViewController.svg?style=flat)](https://cocoapods.org/pods/MERPageViewController)
[![Platform](https://img.shields.io/cocoapods/p/MERPageViewController.svg?style=flat)](https://cocoapods.org/pods/MERPageViewController)

<p>Custom horizontal slide page view controller.</p>
一款自定义的横滑样式分页控制器

## ScreenShots
<p><img src="https://github.com/Mervin1024/MERPageViewController/blob/master/Example/ScreenShoot/Jul-23-2019 15-59-37.gif?raw=true" width="20%" height="20%"></p>
<p><img src="https://github.com/Mervin1024/MERPageViewController/blob/master/Example/ScreenShoot/Jul-23-2019 15-54-33.gif?raw=true" width="20%" height="20%"></p>

## Support

Objective-C & iOS 8+.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

```
self.pageViewController = [[MERPageViewController alloc] init];
self.pageViewController.dataSource = self;
self.pageViewController.delegate = self;
[self addChildViewController:self.pageViewController];
[self.view addSubview:self.pageViewController.view];
self.pageViewController.view.frame = [UIScreen mainScreen].bounds;
```
Required dataSource
```
#pragma mark ----------------- MERPageViewControllerDataSource -----------------

- (nonnull UIViewController *)mer_pageViewController:(nonnull MERPageViewController *)pageViewController controllerAtIndex:(NSInteger)index {
return [self.pageControllers objectAtIndex:index];
}

- (NSInteger)numberOfControllersInPageViewController:(nonnull MERPageViewController *)pageViewController {
return self.pageControllers.count;
}
```

## Installation

MERPageViewController is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'MERPageViewController'
```

## Author

👤 **Mervin1024** mervin1024@163.com

## License

MERPageViewController is available under the MIT license. See the LICENSE file for more info.
