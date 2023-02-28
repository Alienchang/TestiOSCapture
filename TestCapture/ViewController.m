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
@property (nonatomic ,strong) UIView *detectFrameView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.camera = [WLCamera new];
    [self.camera configPreviewOnView:self.view atIndex:0];
    [self.camera startCatpure];
    __weak typeof(self) weakSelf = self;
    self.camera.detectBlock = ^(CGRect frame) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.detectFrameView.frame = frame;
            NSLog(@"frame %@",NSStringFromCGRect(frame));
        });
    };
    [self.view addSubview:self.detectFrameView];
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//
//    });
}

#pragma mark -- getter
- (UIView *)detectFrameView {
    if (!_detectFrameView) {
        _detectFrameView = [UIView new];
        _detectFrameView.layer.borderColor = UIColor.redColor.CGColor;
        _detectFrameView.layer.borderWidth = 1;
    }
    return _detectFrameView;
}
@end
