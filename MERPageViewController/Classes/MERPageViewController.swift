//
//  MERPageViewController.swift
//  MERPageViewController
//
//  Created by mayao's Mac on 2020/12/1.
//

import UIKit

private class MERQueuingScrollView: UIScrollView {
    
}

private extension UIViewController {
    func mer_addChildViewController(_ controller: UIViewController, in view: UIView, frame: CGRect) {
        let contains = self.children.contains(controller)
        if !contains {
            self.addChild(controller)
        }
        controller.view.frame = frame
        if !view.subviews.contains(controller.view) {
            view.addSubview(controller.view)
        }
        if !contains {
            controller.didMove(toParent: self)
        }
    }
    
    func mer_removeFromParentViewController() {
        if self.parent == nil {
            return
        }
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        self.removeFromParent()
    }
    
    static let mer_reusableIdentifierKey = UnsafeRawPointer.init(bitPattern: "mer_reusableIdentifierKey".hashValue)!
    var mer_reusableIdentifier: String? {
        set {
            objc_setAssociatedObject(self, UIViewController.mer_reusableIdentifierKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            objc_getAssociatedObject(self, UIViewController.mer_reusableIdentifierKey) as? String
        }
    }

}

@objc public protocol MERPageViewControllerDelegate {
    /// 即将发起切换
    @objc optional func mer_pageViewController(_ controller: MERPageViewController,
                                               willTransitionFrom: Int,
                                               to: Int,
                                               transitionType: MERPageViewController.TransitionType,
                                               animated: Bool)
    
    /// 完成一次切换
    @objc optional func mer_pageViewController(_ controller: MERPageViewController,
                                               didTransitionFrom: Int,
                                               to: Int,
                                               transitionType: MERPageViewController.TransitionType,
                                               animated: Bool)
    
    /// scrollView 滑动代理
    @objc optional func mer_pageViewController(_ controller: MERPageViewController,
                                               scrollViewDidScroll: UIScrollView,
                                               transitionType: MERPageViewController.TransitionType)
    
}

@objc public protocol MERPageViewControllerDataSource {
    func numberOfControllers(in controller: MERPageViewController) -> Int
    func mer_pageViewController(_ controller: MERPageViewController, controllerAt index: Int) -> UIViewController
}

open class MERPageViewController: UIViewController {
    //MARK: --- Private ---
    private enum PageDirection {
        case left
        case right
    }
    
    /// 用来记录当前屏幕内，静止或滚动时，至多出现的两个页面的位置和滚动方向
    /// 当 from == to 时代表滚动停止，当前屏幕仅显示了一个 VC
    private struct VisibleIndexs: Equatable {
        var from: Int = 0
        var to: Int = 0
        init(_ i: Int) {
            from = i
            to = i
        }
        func contains(_ index: Int) -> Bool {
            from == index || to == index
        }
        /// 滑动过程中，屏幕至多显示两个 vc
        mutating func scroll(to: Int) {
            self.from = self.to
            self.to = to
        }
        /// 滑动结束，visible 实际为一个 index，就是 currentIndex
        mutating func end(at i: Int) {
            self.from = i
            self.to = i
        }
    }
    
    /// 屏幕内需要展示的页面编号
    private var visibleIndexs = VisibleIndexs(0)
    /// 记录是否正在执行切换伪动画
    private var isSwitchAnimating = false
    /// 记录执行伪动画的开始时间，用来过滤多个动画执行时，前几个动画的回调
    private var switchAnimationBeginTime: TimeInterval?
    
    private var firstWillAppear = true
    private var firstDidAppear = true
    private var firstDidLayoutSubViews = true
    
    private lazy var queuingScrollView: MERQueuingScrollView = {
        let scrollView = MERQueuingScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isPagingEnabled = true
        scrollView.backgroundColor = .clear
        scrollView.scrollsToTop = false
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            self.automaticallyAdjustsScrollViewInsets = false
        }
        return scrollView
    }()
    private lazy var queuingScrollViewConstraints = [NSLayoutConstraint]()
    private lazy var switchAnimationContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }()
    /// 用来保留当前展示及需要展示的 VC，与重用池相斥
    private lazy var cache: MERLRUCache<(Int, UIViewController)> = {
        let cache = MERLRUCache<(Int, UIViewController)>()
        cache.name = "MERPageViewControllerCache"
        /// 这个值请勿随便修改，可能引起 bug
        /// 往大了改还好说，往小了改必出问题
        cache.countLimit = 3
        cache.shouldRemoveAllObjectsOnMemoryWarning = false
        cache.shouldRemoveAllObjectsWhenEnteringBackground = false
        cache.setWillEvictCallback { [weak self] in
            self?.cacheWillEvict($0)
        }
        cache.setDidEnterBackgroundCallback { [weak self] in
            self?.cacheDidEnterBackground()
        }
        cache.setDidReceiveMemoryWarningCallback { [weak self] in
            self?.cacheDidReceiveMemoryWarning()
        }
        return cache
    }()
    /// 即将被从列表页面中移出的 VC 集合
    private lazy var childDelayRemoveSet = Set<UIViewController>()
    
    private lazy var registerMap = [String : Set<UIViewController>]()
    
    /// 从 scrollView 移除 vc，并回收入到重用池
    private func putReusableControllerIntoPool(_ vc: UIViewController) {
        vc.mer_removeFromParentViewController()
        if let identifier = vc.mer_reusableIdentifier {
            registerMap[identifier]?.insert(vc)
        }
    }
    
    private func cacheWillEvict(_ obj: (Int, UIViewController)) {
        let index = obj.0
        let vc = obj.1
        /**
         -------------------------------------------------------------------------------------
         childDelayRemoveSet 仅作为容错机制存在，理论上逻辑不出错的情况下，不会使用到 childDelayRemoveSet
         -------------------------------------------------------------------------------------
         */
        /// 当 queuingScrollView 处于 isDragging 状态，Tracking 和 Decelerating 状态都是 NO。
        /// 判断全部为 NO ，代表着缓存清除不是由连续的页面交互触发的
        if !self.queuingScrollView.isDragging,
           !self.queuingScrollView.isTracking,
           !self.queuingScrollView.isDecelerating {
            if visibleIndexs.contains(index) {
                /// 加入 延迟 remove 集合，等待后续机会移除
                self.childDelayRemoveSet.insert(vc)
            }
        } else if (self.queuingScrollView.isDragging) {
            let range = max(0, visibleIndexs.from - 1)...min(visibleIndexs.from + 1, self.pageCount)
            if range.contains(index) {
                /// 加入 延迟 remove 集合，等待后续机会移除
                self.childDelayRemoveSet.insert(vc)
            }
        }
        if !self.childDelayRemoveSet.contains(vc) {
            /// 对于没有加入 延迟 remove 集合的 vc，直接移除
            self.putReusableControllerIntoPool(vc)
        }
    }
    
    private func cacheDidEnterBackground() {
        DispatchQueue.main.async {
            self.clearChildDelayRemoveSet()
        }
    }
    
    private func cacheDidReceiveMemoryWarning() {
        DispatchQueue.main.async {
            self.clearChildDelayRemoveSet()
        }
    }
    
    private var pageCount: Int {
        guard let dataSource = self.dataSource else { return 0 }
        return dataSource.numberOfControllers(in: self)
    }
    
    private func controller(at index: Int, request: Bool = true) -> UIViewController? {
        guard index >= 0, index < self.pageCount else { return nil }
        if let (_, controller) = self.cache[index] {
            return controller
        }
        if request, let dataSource = self.dataSource {
            let controller = dataSource.mer_pageViewController(self, controllerAt: index)
            self.cache[index] = (index, controller)
            return controller
        }
        return nil
    }
    
    private func addVisibleViewController(for index: Int) {
        guard index >= 0, index < self.pageCount else { return }
        guard let controller = self.controller(at: index) else { return }
        let offset = self.calculateVisibleViewOffset(for: index)
        let frame = CGRect(origin: offset, size: self.queuingScrollView.frame.size)
        self.mer_addChildViewController(controller, in: self.queuingScrollView, frame: frame)
    }
    
    private func addPreloadViewController() {
        let _ = self.controller(at: currentIndex)
        self.addVisibleViewController(for: currentIndex - 1)
        self.addVisibleViewController(for: currentIndex + 1)
    }
    
    private func clearChildDelayRemoveSet() {
        /// 不要把当前页面移出
        if let currentVC = self.currentViewController, self.childDelayRemoveSet.contains(currentVC) {
            self.childDelayRemoveSet.remove(currentVC)
            self.cache[currentIndex] = (currentIndex, currentVC)
        }
        /// 从父 View 移出其他所有的 VC
        self.childDelayRemoveSet.forEach({
            self.putReusableControllerIntoPool($0)
        })
        self.childDelayRemoveSet.removeAll()
    }
    
    //MARK: --- Calculate ---
    private func calculateVisibleViewOffset(for index: Int) -> CGPoint {
        let viewWidth = self.queuingScrollView.frame.width
        let maxWidth = self.queuingScrollView.contentSize.width
        var offsetX = CGFloat(index) * viewWidth
        if maxWidth > 0 {
            offsetX = min(offsetX, maxWidth - viewWidth)
        }
        offsetX = max(0, offsetX)
        return .init(x: offsetX, y: 0)
    }
    
    private func calculatePageIndex(fromOffsetX x: CGFloat) -> Int {
        let index = Int(floor(x / self.queuingScrollView.frame.width))
        return max(0, index)
    }
    
    //MARK: --- Override ---
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.view.addSubview(self.queuingScrollView)
        self.queuingScrollViewConstraints = [
            NSLayoutConstraint(item: self.queuingScrollView,
                               attribute: .leading,
                               relatedBy: .equal,
                               toItem: self.view,
                               attribute: .leading,
                               multiplier: 1,
                               constant: self.contentInsets.left),
            NSLayoutConstraint(item: self.queuingScrollView,
                               attribute: .trailing,
                               relatedBy: .equal,
                               toItem: self.view,
                               attribute: .trailing,
                               multiplier: 1,
                               constant: -self.contentInsets.right),
            NSLayoutConstraint(item: self.queuingScrollView,
                               attribute: .top,
                               relatedBy: .equal,
                               toItem: self.view,
                               attribute: .top,
                               multiplier: 1,
                               constant: self.contentInsets.top),
            NSLayoutConstraint(item: self.queuingScrollView,
                               attribute: .bottom,
                               relatedBy: .equal,
                               toItem: self.view,
                               attribute: .bottom,
                               multiplier: 1,
                               constant: -self.contentInsets.bottom)
        ]
        self.view.addConstraints(self.queuingScrollViewConstraints)
        self.view.addSubview(self.switchAnimationContentView)
        self.switchAnimationContentView.isHidden = true
        self.view.addConstraints([
            NSLayoutConstraint(item: self.switchAnimationContentView,
                               attribute: .centerX,
                               relatedBy: .equal,
                               toItem: self.queuingScrollView,
                               attribute: .centerX,
                               multiplier: 1,
                               constant: 0),
            NSLayoutConstraint(item: self.switchAnimationContentView,
                               attribute: .centerY,
                               relatedBy: .equal,
                               toItem: self.queuingScrollView,
                               attribute: .centerY,
                               multiplier: 1,
                               constant: 0),
            NSLayoutConstraint(item: self.switchAnimationContentView,
                               attribute: .width,
                               relatedBy: .equal,
                               toItem: self.queuingScrollView,
                               attribute: .width,
                               multiplier: 1,
                               constant: 0),
            NSLayoutConstraint(item: self.switchAnimationContentView,
                               attribute: .height,
                               relatedBy: .equal,
                               toItem: self.queuingScrollView,
                               attribute: .height,
                               multiplier: 1,
                               constant: 0)
        ])
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let currentController = self.controller(at: currentIndex)
        if firstWillAppear {
            firstWillAppear = false
            visibleIndexs.end(at: currentIndex)
            self.willTransition(from: visibleIndexs.from, to: visibleIndexs.to, transitionType: .switching, animated: false)
            self.delegate?.mer_pageViewController?(self, willTransitionFrom: visibleIndexs.from, to: visibleIndexs.to, transitionType: .switching, animated: false)
        }
        /// 必须与 -endAppearanceTransition 成对出现
        currentController?.beginAppearanceTransition(true, animated: animated)
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let currentController = self.controller(at: currentIndex)
        if firstDidAppear {
            firstDidAppear = false
            self.didTransition(from: visibleIndexs.from, to: visibleIndexs.to, transitionType: .switching, animated: false)
            self.delegate?.mer_pageViewController?(self, didTransitionFrom: visibleIndexs.from, to: visibleIndexs.to, transitionType: .switching, animated: false)
            self.visibleIndexs.end(at: currentIndex)
            if needPreload {
                self.addPreloadViewController()
            }
        }
        currentController?.endAppearanceTransition()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if firstDidLayoutSubViews {
            firstDidLayoutSubViews = false
            /// fix bug: 当使用 UINavigationController 来 push 一个包含 UIScrollView 的 UIViewController 时，可能滚动到负偏移量
            if let navi = self.navigationController, navi.topViewController === self {
                self.queuingScrollView.contentOffset = .zero
                self.queuingScrollView.contentInset = .zero
            }
            DispatchQueue.main.async {
                self.updateScrollViewLayoutIfNeeded()
                self.updateScrollViewDisplayIndexIfNeeded()
            }
        } else {
            DispatchQueue.main.async {
                self.updateScrollViewLayoutIfNeeded()
            }
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.currentViewController?.beginAppearanceTransition(false, animated: animated)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.currentViewController?.endAppearanceTransition()
    }
    
    override open var shouldAutomaticallyForwardAppearanceMethods: Bool {
        false
    }
    
    //MARK: --- Public ---
    @objc public enum TransitionType: Int {
        case dragging
        case switching
    }
    
    @objc public weak var delegate: MERPageViewControllerDelegate?
    @objc public weak var dataSource: MERPageViewControllerDataSource?
    
    @objc public var contentInsets: UIEdgeInsets = .zero {
        didSet {
            guard oldValue != contentInsets else { return }
            guard self.isViewLoaded else { return }
            self.queuingScrollViewConstraints.forEach({
                switch $0.firstAttribute {
                case .leading:
                    $0.constant = contentInsets.left
                case .trailing:
                    $0.constant = -contentInsets.right
                case .top:
                    $0.constant = contentInsets.top
                case .bottom:
                    $0.constant = -contentInsets.bottom
                default:
                    break
                }
            })
            self.queuingScrollView.layoutIfNeeded()
        }
    }
    
    @objc public private(set) var currentIndex: Int = 0
    @objc public var currentViewController: UIViewController? {
        self.cache[currentIndex]?.1
    }
    
    /// 是否支持弹性效果，默认为 true
    @objc public var pageBounces: Bool {
        set {
            self.queuingScrollView.bounces = newValue
        }
        get {
            self.queuingScrollView.bounces
        }
    }
    
    /// 页面是否支持滑动切换，默认为 true
    @objc public var pageScrollEnable: Bool {
        set {
            self.queuingScrollView.isScrollEnabled = newValue
        }
        get {
            self.queuingScrollView.isScrollEnabled
        }
    }
    
    /// 是否需要预加载（滑动结束时加载左右两边的 VC）
    @objc public var needPreload = false
        
    ///  通过代码直接更改当前显示 VC，区别于手部拖动更改 VC
    ///
    ///  采用模拟滚动动画的形式做切换，并没有使用 UIScrollView 的 setContentOffset 动画
    ///  由于不相邻的视图通过 contentOffset 动画滚动，无法做到两个 view 贴合无缝滚动，会导致 scroll 过程中所有的 VC 都会被遍历一遍
    ///
    ///  模拟动画将两个 view 放到视图顶端，做切换动画，完成后放回原位置
    ///
    /// - Parameters:
    ///   - index: 目标位置
    ///   - animated: 是否以动画形式切换
    ///   - completion: 完成回调
    @objc public func showPage(at index: Int, animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        guard index >= 0, index < self.pageCount else { return }
        
        let oldVisibleIndexs = self.visibleIndexs
        self.visibleIndexs.scroll(to: Int(index))
        /// 动画期间使用预先保存的 index
        let visible = self.visibleIndexs
        self.currentIndex = self.visibleIndexs.to
        
        /// 判断 scrollView 是否初始化成功并 displayed 完成
        guard self.queuingScrollView.frame.width > 0 && self.queuingScrollView.contentSize.width > 0 else {
            return
        }
        guard let fromVC = self.controller(at: visible.from),
              let toVC = self.controller(at: visible.to) else {
            return
        }
        /// 滚动执行之前的处理
        func scrollBeforeAnimation() {
            self.isSwitchAnimating = true
            self.queuingScrollView.panGestureRecognizer.isEnabled = false
            self.switchAnimationContentView.isHidden = false
            /// 添加对应的 VC 到 scrollView 上，并通知代理
            self.willTransition(from: visible.from, to: visible.to, transitionType: .switching, animated: animated)
            self.delegate?.mer_pageViewController?(self, willTransitionFrom: visible.from, to: visible.to, transitionType: .switching, animated: animated)
            self.addVisibleViewController(for: visible.to)
            toVC.beginAppearanceTransition(true, animated: animated)
            if visible.to != visible.from {
                fromVC.beginAppearanceTransition(false, animated: animated)
            }
        }
        /// 伪动画执行完成时的处理
        /// 如果不采用动画形式，将直接调用该 block
        func scrollAnimationCompleted() {
            self.queuingScrollView.setContentOffset(self.calculateVisibleViewOffset(for: visible.to), animated: false)
        }
        /// 滚动执行结束后的处理
        func scrollAfterAnimation() {
            self.isSwitchAnimating = false
            self.queuingScrollView.panGestureRecognizer.isEnabled = true
            self.switchAnimationContentView.isHidden = true
            
            toVC.endAppearanceTransition()
            if visible.to != visible.from {
                fromVC.endAppearanceTransition()
            }
            /// 通知结束代理，并清掉不显示的 VC
            self.didTransition(from: visible.from, to: visible.to, transitionType: .switching, animated: animated)
            self.delegate?.mer_pageViewController?(self, didTransitionFrom: visible.from, to: visible.to, transitionType: .switching, animated: animated)
            self.visibleIndexs.end(at: visible.to)

            if needPreload {
                self.addPreloadViewController()
            }
            self.clearChildDelayRemoveSet()
        }
        
        /// 执行伪切换动画
        scrollBeforeAnimation()
        guard animated == true, visible.from != visible.to else {
            /// 以无动画形式结束此次切换
            scrollAnimationCompleted()
            scrollAfterAnimation()
            completion?(true)
            return
        }
        let pageSize = self.queuingScrollView.frame.size
        let direction: PageDirection = visible.from < visible.to ? .right : .left
        let duration: TimeInterval = 0.3
        
        /// 用来重置被用来执行伪动画的 VC 的位置
        func moveChild(_ child: UIViewController?, backToOriginPosition index: Int) {
            guard index >= 0, index < self.pageCount else { return }
            guard let controller = child, controller.parent != nil else { return }
            let origin = self.calculateVisibleViewOffset(for: index)
            if controller.view.frame.minX != origin.x {
                controller.view.frame = {
                    var frame = controller.view.frame
                    frame.origin = origin
                    return frame
                }()
            }
            if !self.queuingScrollView.subviews.contains(controller.view) {
                self.queuingScrollView.addSubview(controller.view)
            }
        }
        /// 取消之前未完成的动画
        self.switchAnimationContentView.layer.removeAllAnimations()
        /// 将不用于此次动画的 view 放置回 scrollView 的原位
        if oldVisibleIndexs.from != visible.from || oldVisibleIndexs.from != visible.to, let (_, oldSelectedVC) = self.cache[oldVisibleIndexs.from] {
            moveChild(oldSelectedVC, backToOriginPosition: oldVisibleIndexs.from)
        }
        /// 记录当前动画时间
        let currentBeginTime = CACurrentMediaTime()
        self.switchAnimationBeginTime = currentBeginTime
        /// 计算动画需要的坐标
        let fromViewStartOrigin: CGPoint = .zero
        let toViewStartOrigin: CGPoint = {
            var origin = fromViewStartOrigin
            switch direction {
            case .right:
                origin.x += pageSize.width
            case .left:
                origin.x -= pageSize.width
            }
            return origin
        }()
        let fromViewAnimateToOrigin: CGPoint = {
            var origin = fromViewStartOrigin
            switch direction {
            case .right:
                origin.x -= pageSize.width
            case .left:
                origin.x += pageSize.width
            }
            return origin
        }()
        let toViewAnimateToOrigin = fromViewStartOrigin
        
        self.switchAnimationContentView.addSubview(fromVC.view)
        self.switchAnimationContentView.addSubview(toVC.view)
        fromVC.view.frame = .init(origin: fromViewStartOrigin, size: pageSize)
        toVC.view.frame = .init(origin: toViewStartOrigin, size: pageSize)
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
            fromVC.view.frame = .init(origin: fromViewAnimateToOrigin, size: pageSize)
            toVC.view.frame = .init(origin: toViewAnimateToOrigin, size: pageSize)
        } completion: { (_) in
            scrollAnimationCompleted()
            /// 被打断的动画不执行以下操作
            let completed = self.switchAnimationBeginTime == currentBeginTime
            if completed {
                moveChild(toVC, backToOriginPosition: visible.to)
                moveChild(fromVC, backToOriginPosition: visible.from)
                scrollAfterAnimation()
            }
            completion?(completed)
        }
    }
    
    /// 刷新过后仅保留当前 vc 在 页面上，其余将被 remove
    @objc public func reloadData() {
        if self.pageCount == 0 {
            currentIndex = 0
            visibleIndexs.end(at: currentIndex)
            self.cache.removeAll()
            self.childDelayRemoveSet.forEach({
                self.putReusableControllerIntoPool($0)
            })
            self.childDelayRemoveSet.removeAll()
            self.updateScrollViewLayoutIfNeeded()
            self.updateScrollViewDisplayIndexIfNeeded()
            return
        }
        
        currentIndex = min(currentIndex, self.pageCount - 1)
        self.cache.removeAll()
        self.childDelayRemoveSet.forEach({
            self.putReusableControllerIntoPool($0)
        })
        self.childDelayRemoveSet.removeAll()
        
        let currentVC = self.controller(at: currentIndex)
        currentVC?.beginAppearanceTransition(true, animated: false)
        self.updateScrollViewLayoutIfNeeded()
        self.updateScrollViewDisplayIndexIfNeeded()
        currentVC?.endAppearanceTransition()
        if needPreload {
            self.addPreloadViewController()
        }
    }
    
    /// 更新 PageViewController 的 contentSize
    @objc public func updateScrollViewLayoutIfNeeded() {
        guard self.queuingScrollView.frame.width > 0 else { return }
        let width = CGFloat(self.pageCount) * self.queuingScrollView.frame.width
        let height = self.queuingScrollView.frame.height
        let contentSize = CGSize(width: width, height: height)
        if contentSize != self.queuingScrollView.contentSize {
            self.queuingScrollView.contentSize = contentSize
        }
    }
    
    /// 重定位 PageViewController 的 offset 至当前页面的 minX
    @objc public func updateScrollViewDisplayIndexIfNeeded() {
        guard self.queuingScrollView.frame.width > 0 else { return }
        self.addVisibleViewController(for: currentIndex)
        let newOffset = self.calculateVisibleViewOffset(for: currentIndex)
        if newOffset != self.queuingScrollView.contentOffset {
            self.queuingScrollView.contentOffset = newOffset
        }
    }

}

//MARK: --- Subclass Override ---
extension MERPageViewController {
    /// 子类 override，即将切换时被调用
    @objc open func willTransition(from: Int, to: Int, transitionType: TransitionType, animated: Bool) {}
    /// 子类 override，完成切换时被调用
    @objc open func didTransition(from: Int, to: Int, transitionType: TransitionType, animated: Bool) {}
}

extension MERPageViewController: UIScrollViewDelegate {
    /// 根据位置，重新更新当前显示 VC，在切换结束时调用
    private func updatePageViewAfterTragging(_ scrollView: UIScrollView) {
        guard !isSwitchAnimating else { return }
        let toIndex = self.calculatePageIndex(fromOffsetX: scrollView.contentOffset.x)
        let fromIndex = currentIndex
        if toIndex == fromIndex && visibleIndexs.to == visibleIndexs.from {
            /// 在边界位置向边界外拖动，不做操作
            return
        }
        let oldVisible = self.visibleIndexs
        visibleIndexs.end(at: toIndex)
        currentIndex = toIndex
        
        /// 最终确定的位置与开始位置相同时，需要重新显示开始位置的视图，以及 dismiss 最近一次猜测的位置的视图。
        if oldVisible.from == toIndex, oldVisible.from != oldVisible.to {
            self.controller(at: oldVisible.to, request: false)?.beginAppearanceTransition(false, animated: true)
            self.controller(at: toIndex, request: false)?.beginAppearanceTransition(true, animated: true)
            self.controller(at: oldVisible.to, request: false)?.endAppearanceTransition()
            self.controller(at: toIndex, request: false)?.endAppearanceTransition()
        } else {
            self.controller(at: oldVisible.from, request: false)?.endAppearanceTransition()
            self.controller(at: toIndex, request: false)?.endAppearanceTransition()
        }
        
        self.didTransition(from: fromIndex, to: visibleIndexs.to, transitionType: .dragging, animated: true)
        self.delegate?.mer_pageViewController?(self, didTransitionFrom: fromIndex, to: visibleIndexs.to, transitionType: .dragging, animated: true)
        if needPreload {
            self.addPreloadViewController()
        }
        self.clearChildDelayRemoveSet()
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.delegate?.mer_pageViewController?(self, scrollViewDidScroll: scrollView, transitionType: isSwitchAnimating ? .switching : .dragging)
        guard !isSwitchAnimating else { return }
        
        let offsetX = scrollView.contentOffset.x
        let width = scrollView.frame.width
        let oldVisible = visibleIndexs
        let pageCount = self.pageCount

        let left = max(0, Int(floor(offsetX / width)))
        let right = min(Int(ceil(offsetX / width)), pageCount)
        
        if left < oldVisible.from, left < oldVisible.to {
            visibleIndexs.to = left
            visibleIndexs.from = right
        } else if right > oldVisible.from, right > oldVisible.to {
            visibleIndexs.to = right
            visibleIndexs.from = left
        }
        
        /// 过滤掉无效跳转（目标相同或者越界）
        guard oldVisible != visibleIndexs, left < right else { return }

        /// 这里的几次调用 controller(at: 的顺序会影响 cache 内部 lru 排序，进而影响 child 的 Appearance 方法调用顺序
        let oldFromVC = self.controller(at: oldVisible.from, request: false)
        let oldToVC = self.controller(at: oldVisible.to, request: false)
        let fromVC = self.controller(at: visibleIndexs.from)
        let toVC = self.controller(at: visibleIndexs.to)
        if visibleIndexs.to != currentIndex {
            self.willTransition(from: currentIndex, to: visibleIndexs.to, transitionType: .dragging, animated: true)
            self.delegate?.mer_pageViewController?(self, willTransitionFrom: currentIndex, to: visibleIndexs.to, transitionType: .dragging, animated: true)
        }
        
        /// 当前滑动之上还有一次未完成滑动
        if oldVisible.from != oldVisible.to {
            if oldVisible.to != visibleIndexs.to, oldVisible.from == visibleIndexs.from {
                oldToVC?.beginAppearanceTransition(false, animated: true)
                fromVC?.beginAppearanceTransition(true, animated: true)
                oldToVC?.endAppearanceTransition()
                fromVC?.endAppearanceTransition()
            } else {
                oldFromVC?.endAppearanceTransition()
                fromVC?.endAppearanceTransition()
            }
        }
        self.addVisibleViewController(for: visibleIndexs.to)
        /// 处理 VC 的生命周期
        fromVC?.beginAppearanceTransition(false, animated: true)
        toVC?.beginAppearanceTransition(true, animated: true)
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if !scrollView.isDragging {
            self.updatePageViewAfterTragging(scrollView)
        }
    }
        
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        /// 手指抬起的时候，刚好不需要任何减速就停留在目标位置，则主动调用刷新 page
        if Int(scrollView.contentOffset.x * 100) % Int(scrollView.frame.width * 100) == 0 {
            self.updatePageViewAfterTragging(scrollView)
        }
    }
}

/// Child 重用类需要遵守此协议
@objc public protocol MERPageReusable: NSObjectProtocol {
    @objc optional func prepareForReuse()
}

/// Child 重用拓展
extension MERPageViewController {
    public typealias ReusableController = UIViewController & MERPageReusable
    
    /// 注册可重用的 ViewController 类型
    @objc public func register(_ childClass: ReusableController.Type) {
        let identifier = "\(childClass)"
        if self.registerMap[identifier] == nil {
            self.registerMap[identifier] = Set<UIViewController>()
        }
    }
    
    /// Swift 方法，泛型调用
    /// exp: let vc: MERPageViewController = self.dequeueReusableChild(for: 0)
    public func dequeueReusableChild<T: ReusableController>(for index: Int) -> T {
        let identifier = "\(T.self)"
        guard let _ = self.registerMap[identifier] else { fatalError("This class (\(identifier)) is not registered") }
        if let controller = self.registerMap[identifier]?.popFirst() as? T {
            controller.prepareForReuse?()
            return controller
        } else {
            let controller = T.init()
            controller.mer_reusableIdentifier = identifier
            return controller
        }
    }

    @objc public func dequeueReusableChild(_ childClass: ReusableController.Type, for index: Int) -> ReusableController {
        let identifier = "\(childClass)"
        guard let _ = self.registerMap[identifier] else { fatalError("This class (\(identifier)) is not registered") }
        if let controller = self.registerMap[identifier]?.popFirst() as? ReusableController {
            controller.prepareForReuse?()
            return controller
        } else {
            let controller = childClass.init()
            controller.mer_reusableIdentifier = identifier
            return controller
        }
    }
}
