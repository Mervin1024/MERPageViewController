//
//  ViewController_Swift.swift
//  MERPageViewController_Example
//
//  Created by mayao's Mac on 2020/12/4.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import MERPageViewController

class ViewController_Swift: UIViewController {
    lazy var pageViewController: MERPageViewController = {
        let controller = MERPageViewController()
        controller.delegate = self
        controller.dataSource = self
        controller.isPreloadEnabled = true
//        controller.pageBounces = false
        return controller
    }()
    
    lazy var dataArray = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(pageViewController.view)
        self.addChild(pageViewController)
        pageViewController.view.frame = self.view.bounds
        pageViewController.register(ChildViewController.self)

        for i in 0..<6 {
            dataArray.append(i.description)
        }
        
        let button = UIButton(type: .system)
        button.setTitle("随机跳转", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 30)
        button.sizeToFit()
        button.center = .init(x: self.view.center.x, y: self.view.center.y - 100)
        button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        self.view.addSubview(button)
    }
    
    @objc private func buttonPressed() {
        var target = 0
        repeat {
            target = Int(arc4random()%UInt32(dataArray.count))
        } while target == pageViewController.currentIndex
        self.pageViewController.showPage(at: target)
    }
}

extension ViewController_Swift: MERPageViewControllerDataSource, MERPageViewControllerDelegate {
    func numberOfControllers(in controller: MERPageViewController) -> Int {
        dataArray.count
    }
    
    func mer_pageViewController(_ controller: MERPageViewController, controllerAt index: Int) -> UIViewController {
        let child: ChildViewController = controller.dequeueReusableChild(for: index)
        child.name = dataArray[index]
        return child
    }
    
    func mer_pageViewController(_ controller: MERPageViewController, willTransition from: Int, to: Int, transitionType: MERPageViewController.TransitionType, animated: Bool) {
//        print("willTransitionFrom \(from.description)  to \(to.description)")
    }
    
    func mer_pageViewController(_ controller: MERPageViewController, didTransition from: Int, to: Int, transitionType: MERPageViewController.TransitionType, animated: Bool) {
//        print("didTransitionFrom \(from.description)  to \(to.description)")
    }
    
}

class ChildViewController: UIViewController, MERPageReusable {
    var name: String = "" {
        didSet {
            label.text = name
            self.view.setNeedsLayout()
        }
    }
    let label = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(red: CGFloat(arc4random() % 255) / 255, green: CGFloat(arc4random() % 255) / 255, blue: CGFloat(arc4random() % 255) / 255, alpha: 1)
        label.text = self.name
        label.font = .boldSystemFont(ofSize: 26)
        label.sizeToFit()
        self.view.addSubview(label)
        label.center = self.view.center
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        label.sizeToFit()
    }
    
    func prepareForReuse() {
        print("controller: \(name) - prepareForReuse")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("controller: \(name) - viewWillAppear: \(animated.description)")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("controller: \(name) - viewDidAppear: \(animated.description)")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("controller: \(name) - viewWillDisappear: \(animated.description)")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("controller: \(name) - viewDidDisappear: \(animated.description)")
    }
    
//    override func beginAppearanceTransition(_ isAppearing: Bool, animated: Bool) {
//        super.beginAppearanceTransition(isAppearing, animated: animated)
//        print("controller: \(name) - beginAppearanceTransition: \(isAppearing.description)")
//    }
//
//    override func endAppearanceTransition() {
//        super.endAppearanceTransition()
//        print("controller: \(name) - endAppearanceTransition")
//    }
}
