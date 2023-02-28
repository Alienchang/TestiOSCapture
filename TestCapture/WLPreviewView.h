//
//  WLPreviewView.h
//  TestCapture
//
//  Created by zz on 2023/2/24.
//

#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface WLPreviewView : MTKView
- (void)previewBuffer:(CVPixelBufferRef)buffer;
@end

NS_ASSUME_NONNULL_END
