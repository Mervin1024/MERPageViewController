# MERPageViewController

[![Version](https://img.shields.io/cocoapods/v/MERPageViewController.svg?style=flat)](https://cocoapods.org/pods/MERPageViewController)
[![License](https://img.shields.io/cocoapods/l/MERPageViewController.svg?style=flat)](https://cocoapods.org/pods/MERPageViewController)
[![Platform](https://img.shields.io/cocoapods/p/MERPageViewController.svg?style=flat)](https://cocoapods.org/pods/MERPageViewController)

<p>Custom horizontal slide page view controller.</p>
一款自定义的横滑样式分页控制器，能够保证 ChildViewController 的生命周期方法可以正确的被调用，支持动画形式的 index 切换

## ScreenShots
<p><img src="https://github.com/Mervin1024/MERPageViewController/blob/master/Example/ScreenShoot/Jul-23-2019 15-59-37.gif?raw=true" width="20%" height="20%"></p>
<p><img src="https://github.com/Mervin1024/MERPageViewController/blob/master/Example/ScreenShoot/Jul-23-2019 15-54-33.gif?raw=true" width="20%" height="20%"></p>

## Support

Swift 4.2 & iOS 9+.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

```
let pageController = MERPageViewController()
pageController.delegate = self
pageController.dataSource = self
pageController.pageBounces = false

// Automatically loads adjacent pages when you stop
// pageController.isPreloadEnabled = true
```

If you need to use Reusable UIViewController 
```
class AnyViewController: UIViewController, MERPageReusable { }
pageController.register(AnyViewController.self)
```
Required dataSource
```
#pragma mark ----------------- MERPageViewControllerDataSource -----------------

func numberOfControllers(in controller: MERPageViewController) -> Int {
    dataArray.count
}

func mer_pageViewController(_ controller: MERPageViewController, controllerAt index: Int) -> UIViewController {
    /// If you need to use Reusable UIViewController
    let child: AnyViewController = controller.dequeueReusableChild(for: index)
    child.title = dataArray[index]
    return child
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
