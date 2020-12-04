//
//  TestChildViewController.m
//  MERPageViewController_Example
//
//  Created by mayao's Mac on 2020/12/1.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

#import "TestChildViewController.h"

@interface TestChildViewController ()
@property (nonatomic, strong) UILabel *nameLabel;
@end

@implementation TestChildViewController

- (void)setName:(NSString *)name {
    _name = name;
    self.nameLabel.text = [NSString stringWithFormat:@"ViewController : %@", name];
    [self.nameLabel sizeToFit];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor colorWithRed:(arc4random()%255)/255.f green:(arc4random()%255)/255.f blue:(arc4random()%255)/255.f alpha:1];

    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:30];
    label.text = [NSString stringWithFormat:@"ViewController : %@", self.name];
    [label sizeToFit];
    [self.view addSubview:label];
    label.center = CGPointMake([UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/2);
    self.nameLabel = label;
    
    NSLog(@"viewDidLoad :    %@", self.name);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSLog(@"Will Appear :    %@", self.name);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"Did Appear :    %@", self.name);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    NSLog(@"Will Disappear :    %@", self.name);
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    NSLog(@"Did Disappear :    %@", self.name);
}

- (void)prepareForReuse {
    NSLog(@"prepareForReuse :    %@", self.name);
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
