//
//  MERPageLRUCache.h
//  MERPageViewController
//
//  Created by mayao's Mac on 2019/6/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MERPageLRUCacheDelegate;
@interface MERPageLRUCache : NSObject

@property (nullable, assign) id<MERPageLRUCacheDelegate> delegate;

@property (nullable, copy) NSString *name;
@property (readonly) NSUInteger totalCount;

@property NSUInteger countLimit;
@property NSTimeInterval autoTrimInterval;

- (BOOL)containsObjectForKey:(id)key;
- (nullable id)objectForKey:(id)key;
- (void)setObject:(nullable id)object forKey:(id)key;
- (void)removeObjectForKey:(id)key;
- (void)removeAllObjects;

- (void)trimToCount:(NSUInteger)count;

@property BOOL shouldRemoveAllObjectsOnMemoryWarning; // default YES.
@property BOOL shouldRemoveAllObjectsWhenEnteringBackground; // default YES.

@end

@protocol MERPageLRUCacheDelegate <NSObject>
@optional
- (void)cache:(MERPageLRUCache *)cache willEvictObject:(id)obj;
- (void)cacheDidReceiveMemoryWarning:(MERPageLRUCache *)cache ;
- (void)cacheDidEnterBackground:(MERPageLRUCache *)cache ;
@end

NS_ASSUME_NONNULL_END
