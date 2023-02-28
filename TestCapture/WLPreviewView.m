//
//  WLPreviewView.m
//  TestCapture
//
//  Created by zz on 2023/2/24.
//

#import "WLPreviewView.h"
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

@interface WLPreviewView()<MTKViewDelegate>
//处理队列
@property (nonatomic, strong) dispatch_queue_t mProcessQueue;

//纹理缓存区
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;

//命令队列
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;

//纹理
@property (nonatomic, strong) id<MTLTexture> texture;
@end

@implementation WLPreviewView
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.delegate = self;
        self.device = MTLCreateSystemDefaultDevice();
        CVMetalTextureCacheCreate(NULL, NULL, self.device, NULL, &_textureCache);
        self.commandQueue = [self.device newCommandQueue];
        self.framebufferOnly = NO;
        
        self.contentMode = UIViewContentModeScaleAspectFit;
    }
    return self;
}

- (void)previewBuffer:(CVPixelBufferRef)buffer {
    size_t width = CVPixelBufferGetWidth(buffer);
    size_t height = CVPixelBufferGetHeight(buffer);
    
    CVMetalTextureRef tmpTexture = NULL;
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, buffer, NULL, MTLPixelFormatBGRA8Unorm, width, height, 0, &tmpTexture);
    
    
//    4、判断tmpTexture 是否创建成功
    if (status == kCVReturnSuccess) {//创建成功
//        5、设置可绘制纹理的大小
        self.drawableSize = CGSizeMake(width, height);
        
//        6、返回纹理缓冲区的metal纹理对象
        self.texture = CVMetalTextureGetTexture(tmpTexture);
        
//        7、使用完毕，释放tmptexture
        CFRelease(tmpTexture);
    }
}


#pragma mark - MTKView Delegate

//视图大小发生改变时.会调用此方法
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size{
    
}

//视图渲染则会调用此方法
- (void)drawInMTKView:(MTKView *)view{
//    1、判断是否获取了AVFoundation 采集的纹理数据
    if (self.texture) {//有纹理数据
//        2、创建指令缓冲
        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        
//        3、将mtkView中的纹理 作为 目标渲染纹理
         id<MTLTexture> drawingTexture = view.currentDrawable.texture;
        
//        4、设置滤镜（Metal封装了一些滤镜）
        //高斯模糊 渲染时，会触发 离屏渲染
        /*
          MetalPerformanceShaders是Metal的一个集成库，有一些滤镜处理的Metal实现;
          MPSImageGaussianBlur 高斯模糊处理;
          */
        
         //创建高斯滤镜处理filter
         //注意:sigma值可以修改，sigma值越高图像越模糊;
        MPSImageGaussianBlur *filter = [[MPSImageGaussianBlur alloc] initWithDevice:self.device sigma:0];
//        5、MPSImageGaussianBlur以一个Metal纹理作为输入，以一个Metal纹理作为输出；
        //输入:摄像头采集的图像 self.texture
        //输出:创建的纹理 drawingTexture(其实就是view.currentDrawable.texture)
        //filter等价于Metal中的MTLRenderCommandEncoder 渲染命令编码器，类似于GLSL中的program
        [filter encodeToCommandBuffer:commandBuffer sourceTexture:self.texture destinationTexture:drawingTexture];
        
//        6、展示显示的内容
        [commandBuffer presentDrawable:view.currentDrawable];
        
//        7、提交命令
        [commandBuffer commit];
        
//        8、清空当前纹理，准备下一次的纹理数据读取，
        //如果不清空，也是可以的，下一次的纹理数据会将上次的数据覆盖
        self.texture = NULL;
    }
}


@end
