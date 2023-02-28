//
//  WLCamera.h
//  TestCapture
//
//  Created by zz on 2022/10/20.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WLCamera : NSObject
- (void)configPreviewOnView:(UIView *)view
                    atIndex:(NSInteger)index;
- (void)startCatpure;
@property (nonatomic ,copy) void(^detectBlock)(CGRect frame);
@end

NS_ASSUME_NONNULL_END
