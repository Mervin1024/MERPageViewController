//
//  MERTestChildViewController.m
//  MERPageViewController_Example
//
//  Created by mayao's Mac on 2019/5/9.
//  Copyright © 2019 Mervin1024. All rights reserved.
//

#import "MERTestChildViewController.h"

@interface MERTestChildViewController ()

@end

@implementation MERTestChildViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:(arc4random()%255)/255.f green:(arc4random()%255)/255.f blue:(arc4random()%255)/255.f alpha:1];

    UILabel *label = [[UILabel alloc] init];
    label.text = [NSString stringWithFormat:@"ViewController : %@", @(self.index)];
    [label sizeToFit];
    [self.view addSubview:label];
    label.center = CGPointMake([UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/2);
    
//    NSLog(@"viewDidLoad :    %@", @(self.index));
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//    NSLog(@"Will Appear :    %@", @(self.index));
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
//    NSLog(@"Did Appear :    %@", @(self.index));
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
//    NSLog(@"Will Disappear :    %@", @(self.index));
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
//    NSLog(@"Did Disappear :    %@", @(self.index));
}


@end
