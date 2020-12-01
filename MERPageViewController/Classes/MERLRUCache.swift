//
//  MERLRUCache.swift
//  MERPageViewController
//
//  Created by mayao's Mac on 2020/12/1.
//

import Foundation
import UIKit

final public class MERLRUCache<Element> {
    //MARK: --- Private ---
    private var lock = pthread_mutex_t()
    private var lru: MERLinkedMap<Element>
    private var queue: DispatchQueue

    private var willEvictBlock: ((Element) -> Void)?
    private var didReceiveMemoryWarningBlock: (() -> Void)?
    private var didEnterBackgroundBlock: (() -> Void)?

    @objc private func didReceiveMemoryWarningNotification() {
        self.didReceiveMemoryWarningBlock?()
        if self.shouldRemoveAllObjectsOnMemoryWarning {
            self.removeAll()
        }
    }
    
    @objc private func didEnterBackgroundNotification() {
        self.didEnterBackgroundBlock?()
        if self.shouldRemoveAllObjectsWhenEnteringBackground {
            self.removeAll()
        }
    }

    private func trimRecursively() {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + autoTrimInterval) { [weak self] in
            guard let self = self else { return }
            self.trimInBackground()
            self.trimRecursively()
        }
    }
    
    private func trimInBackground() {
        queue.async {
            self._trim(to: self.countLimit)
        }
    }
    
    private func _trim(to count: UInt) {
        var finish = false
        pthread_mutex_lock(&lock)
        if count == 0 {
            lru.removeAll()
            finish = true
        } else if lru.totalCount <= count {
            finish = true
        }
        pthread_mutex_unlock(&lock)
        if finish { return }
        
        let holder = NSMutableArray()
        while !finish {
            if pthread_mutex_trylock(&lock) == 0 {
                if lru.totalCount > count {
                    if let node = lru.removeTailNode() {
                        holder.add(node)
                    }
                } else {
                    finish = true
                }
                pthread_mutex_unlock(&lock)
            } else {
                /// 10 ms
                usleep(10 * 1000)
            }
        }
        if holder.count > 0 {
            /// 异步释放
            queue.async {
                let _ = holder.self
            }
        }
    }

    //MARK: --- Public ---
    /// 只影响 description 的内容
    public var name: String?
    
    /// cache 最大容量，默认 UInt.max
    public var countLimit: UInt = .max
    /// cache 在子线程轮询，检查清理超限数据的时间间隔，默认 5s 一次
    public var autoTrimInterval: TimeInterval = 5
    /// 收到内存警告是否清理 cache，默认 true
    public var shouldRemoveAllObjectsOnMemoryWarning = true
    /// 退到后台是否清理 cache，默认 true
    public var shouldRemoveAllObjectsWhenEnteringBackground = true

    public func setWillEvictCallback(_ callback: ((Element) -> Void)?) {
        willEvictBlock = callback
    }
    
    public func setDidReceiveMemoryWarningCallback(_ callback: (() -> Void)?) {
        didReceiveMemoryWarningBlock = callback
    }
    
    public func setDidEnterBackgroundCallback(_ callback: (() -> Void)?) {
        didEnterBackgroundBlock = callback
    }
    
    public init() {
        pthread_mutex_init(&lock, nil)
        lru = MERLinkedMap()
        queue = DispatchQueue(label: "com.mervin.cache.memory")
        lru.nodeWillBeRemoved = { [weak self] in
            self?.willEvictBlock?($0.value)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarningNotification), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        self.trimRecursively()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        lru.removeAll()
        pthread_mutex_destroy(&lock)
    }

    public var totalCount: UInt {
        pthread_mutex_lock(&lock)
        let count = lru.totalCount
        pthread_mutex_unlock(&lock)
        return count
    }
    
    public func containsObject(for key: AnyHashable) -> Bool {
        pthread_mutex_lock(&lock)
        let contains = lru.dic.contains(where: { $0.key as! AnyHashable == key })
        pthread_mutex_unlock(&lock)
        return contains
    }

    public subscript(key: AnyHashable) -> Element? {
        set {
            guard let value = newValue else {
                remove(for: key)
                return
            }
            pthread_mutex_lock(&lock)
            let node = lru.dic[key] as? MERLinkedMapNode<Element>
            let now = CACurrentMediaTime()
            if let n = node {
                n.time = now
                n.value = value
                lru.bringNodeToHead(n)
            } else {
                let newNode = MERLinkedMapNode(key: key, value: value)
                newNode.time = now
                lru.insertNodeAtHead(newNode)
            }
            if lru.totalCount > countLimit,
               let tail = lru.removeTailNode() {
                /// 异步释放
                queue.async {
                    let _ = tail.self
                }
            }
            pthread_mutex_unlock(&lock)
        }
        get {
            pthread_mutex_lock(&lock)
            let node = lru.dic[key] as? MERLinkedMapNode<Element>
            if let n = node {
                n.time = CACurrentMediaTime()
                lru.bringNodeToHead(n)
            }
            pthread_mutex_unlock(&lock)
            return node?.value
        }
    }

    public func remove(for key: AnyHashable) {
        pthread_mutex_lock(&lock)
        if let node = lru.dic[key] as? MERLinkedMapNode<Element> {
            lru.remove(node)
            queue.async {
                let _ = node.self
            }
        }
        pthread_mutex_unlock(&lock)
    }

    public func removeAll() {
        pthread_mutex_lock(&lock)
        lru.removeAll()
        pthread_mutex_unlock(&lock)
    }

    public func trim(to count: UInt) {
        if count == 0 {
            self.removeAll()
        } else {
            self._trim(to: count)
        }
    }
}

extension MERLRUCache: CustomStringConvertible {
    /// description
    public var description: String {
        let sub1 = "<\(MERLRUCache.self): "
        let sub2 = "\(Unmanaged.passUnretained(self).toOpaque().debugDescription)>"
        if let name = name {
            return sub1 + sub2 + "(\(name))"
        } else {
            return sub1 + sub2
        }
    }
}


private class MERLinkedMapNode<Element> {
    weak var prev: MERLinkedMapNode?
    weak var next: MERLinkedMapNode?
    var value: Element
    let key: AnyHashable
    var time: TimeInterval = 0

    init(key: AnyHashable, value: Element) {
        self.key = key
        self.value = value
    }
}

private class MERLinkedMap<Element> {
    var dic = NSMutableDictionary()
    var totalCount: UInt = 0
    var head: MERLinkedMapNode<Element>?
    var tail: MERLinkedMapNode<Element>?

    var nodeWillBeRemoved: ((MERLinkedMapNode<Element>) -> Void)?

    func insertNodeAtHead(_ node: MERLinkedMapNode<Element>) {
        dic[node.key] = node
        totalCount += 1
        if let _ = head {
            node.next = head
            head?.prev = node
            head = node
        } else {
            head = node
            tail = node
        }
    }

    func bringNodeToHead(_ node: MERLinkedMapNode<Element>) {
        guard head !== node else { return }
        if tail === node {
            tail = node.prev
            tail?.next = nil
        } else {
            node.next?.prev = node.prev
            node.prev?.next = node.next
        }
        node.next = head
        node.prev = nil
        head?.prev = node
        head = node
    }

    func remove(_ node: MERLinkedMapNode<Element>) {
        dic.removeObject(forKey: node.key)
        totalCount -= 1
        if let next = node.next {
            next.prev = node.prev
        }
        if let prev = node.prev {
            prev.next = node.next
        }
        if head === node {
            head = node.next
        }
        if tail === node {
            tail = node.prev
        }
        nodeWillBeRemoved?(node)
    }

    func removeTailNode() -> MERLinkedMapNode<Element>? {
        guard let tempTail = tail else { return nil }
        dic.removeObject(forKey: tempTail.key)
        totalCount -= 1
        if head === tail {
            head = nil
            tail = nil
        } else {
            tail = tail?.prev
            tail?.next = nil
        }
        nodeWillBeRemoved?(tempTail)
        return tempTail
    }

    func removeAll() {
        totalCount = 0
        head = nil
        tail = nil
        if dic.count > 0 {
            for (_, value) in dic {
                if let node = value as? MERLinkedMapNode<Element> {
                    nodeWillBeRemoved?(node)
                }
            }
            dic.removeAllObjects()
        }
    }
}
