//
//  ViewController.m
//  TestCapture
//
//  Created by zz on 2022/10/20.
//

#import "ViewController.h"
#import "WLCamera.h"
@interface ViewController ()
@property (nonatomic ,strong) WLCamera *camera;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.camera = [WLCamera new];
    [self.camera startCatpure];
}


@end
