//
//  WLCamera.m
//  TestCapture
//
//  Created by zz on 2022/10/20.
//

#if __cplusplus && __has_include(<opencv2/imgcodecs/ios.h>)
#import <opencv2/imgproc/types_c.h>
#import <opencv2/core/core.hpp>
#import <opencv2/objdetect/objdetect.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/core.hpp>
#import <opencv2/highgui.hpp>
#import <opencv2/imgproc.hpp>
using namespace cv;
using namespace std;

#endif


#import "WLCamera.h"
#import <AVFoundation/AVFoundation.h>
#import "WLPreviewView.h"
#import <sys/utsname.h>

@interface WLCamera()
<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureDevicePosition *_devicePosition;
}
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice  *device;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *deviceOutput;
@property (nonatomic, strong) AVCaptureConnection *captureConnection;
@property (nonatomic, strong) dispatch_queue_t bufferQueue;
@property (nonatomic, strong) WLPreviewView *previewView;
@property (nonatomic, strong) dispatch_queue_t detectQueue;
@end

@implementation WLCamera
- (instancetype)init {
    if (self = [super init]) {
        self.detectQueue = dispatch_queue_create("kVenusPlanetDataProviderSerialQueue", DISPATCH_QUEUE_CONCURRENT);
        self.bufferQueue = dispatch_queue_create("WLCamera_queue", NULL);
        [self setupCaptureSession];
        [self setupDevice];
        [self setupInput];
        [self setupOutput];
    }
    return self;
}

#pragma mark -- capture
- (void)setupCaptureSession {
    self.captureSession = [AVCaptureSession new];
    [self.captureSession beginConfiguration];
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
        [self.captureSession setSessionPreset:AVCaptureSessionPreset1920x1080];
    }
    [self.captureSession commitConfiguration];
}

- (void)setupDevice {
    self.device = [self captureDeviceWithPosition:(AVCaptureDevicePositionFront)];
    // 一般直播16-18，电影24
    [self setFPS:16];
}

- (void)setupInput {
    NSError *error = nil;
    self.deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:&error];
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddInput:self.deviceInput]) {
        [self.captureSession addInput:self.deviceInput];
    }
    [self.captureSession commitConfiguration];
}

- (void)setupOutput {
    self.deviceOutput = [AVCaptureVideoDataOutput new];
    // 输出下一帧时是否丢弃上一帧
    self.deviceOutput.alwaysDiscardsLateVideoFrames = NO;
    // 输出视频色彩空间为yuv420（也可以为RGB）
    self.deviceOutput.videoSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
    };
    // 设置视频数据输出回调
    [self.deviceOutput setSampleBufferDelegate:self queue:self.bufferQueue];
    
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddOutput:self.deviceOutput]) {
        [self.captureSession addOutput:self.deviceOutput];
    }
    [self.captureSession commitConfiguration];
    
    self.captureConnection = [self.deviceOutput connectionWithMediaType:AVMediaTypeVideo];
    
    
    // 以下功能一定要放在[self.captureSession addOutput:self.deviceOutput] 之下，否则无法获取状态
    // 设置输出图像方向
    if (self.captureConnection.supportsVideoOrientation) {
        self.captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    // 设置是否镜像
    if ([self.captureConnection isVideoMirroringSupported]) {
        [self.captureConnection setVideoMirrored:YES];
    }
    
    
}


#pragma mark -- public func
- (void)configPreviewOnView:(UIView *)view
                    atIndex:(NSInteger)index {
    if (!self.previewView) {
        self.previewView = [[WLPreviewView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    view.clipsToBounds = YES;
    [view insertSubview:self.previewView atIndex:index];
}

- (void)startCatpure {
    if (!(self.device && self.deviceInput && self.deviceOutput)) {
        return;
    }
    
    if (self.captureSession && ![self.captureSession isRunning]) {
        [self.captureSession startRunning];
    }
}

- (void)setFPS:(NSInteger)fps {
    if (fps > 0) {
        AVFrameRateRange *frameRateRange = self.device.activeFormat.videoSupportedFrameRateRanges.firstObject;
        if(!frameRateRange) {
            // 无法获取摄像头
            return;
        }
        if (fps >= frameRateRange.maxFrameRate) {
            fps = frameRateRange.maxFrameRate;
        } else if (fps <= frameRateRange.minFrameRate) {
            fps = frameRateRange.minFrameRate;
        }
        CMTime frameDuration = CMTimeMake(1 , (int)fps);
        [self.captureSession beginConfiguration];
        NSError *error = nil;
        if ([self.device lockForConfiguration:&error]) {
            self.device.activeVideoMaxFrameDuration = frameDuration;
            self.device.activeVideoMinFrameDuration = frameDuration;
            [self.device unlockForConfiguration];
        } else {
            // 设置失败
        }
        [self.captureSession commitConfiguration];
    }
}

#pragma mark -- private func
/// 获取采集设备
- (AVCaptureDevice *)captureDeviceWithPosition:(AVCaptureDevicePosition)position {
    AVCaptureDevice *deviceRet = nil;
    if (position != AVCaptureDevicePositionUnspecified) {
        NSArray<AVCaptureDeviceType> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera,    // 广角镜头
                                                      AVCaptureDeviceTypeBuiltInDualCamera];        // 正常情况下是主摄
        
        AVCaptureDeviceDiscoverySession *sessionDiscovery = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:position];
        
        NSArray<AVCaptureDevice *> *devices = sessionDiscovery.devices;//当前可用的AVCaptureDevice集合
        for (AVCaptureDevice *device in devices) {
            if ([device position] == position) {
                deviceRet = device;
            }
        }
    }
    return deviceRet;
}

#pragma mark -- AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //获取每一帧图像信息
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVImageBufferRef imageBuffer =  CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    dispatch_async(self.detectQueue, ^{
//        NSString *path1 = [NSBundle.mainBundle pathForResource:@"haarcascade_frontalface_alt2" ofType:@"xml"];
        NSString *path2 = [NSBundle.mainBundle pathForResource:@"haarcascade_frontalface_default" ofType:@"xml"];
        
        cv::CascadeClassifier cas_alt2 = cv::CascadeClassifier([path2 cStringUsingEncoding:NSUTF8StringEncoding]);
    //    cv::CascadeClassifier cas_default = cv::CascadeClassifier([path2 cStringUsingEncoding:NSUTF8StringEncoding]);
        std::vector<cv::Rect>squares;
        Mat original = Mat((int)height,(int)width,CV_8UC4,baseAddress);

        double scalingFactor = 1.5;               // 简单理解为尺寸的精细程度
        int minNeighbors = 1;                     // 识别最少几次成功才认为成功识别为一个人脸
        int flags = 0;
        cv::Size miniSize = cv::Size(80, 80);   // 最小可识别区域
        cas_alt2.detectMultiScale(original,
                                  squares,
                                  scalingFactor,
                                  minNeighbors,
                                  flags,
                                  miniSize);

        for (NSInteger i = 0; i < squares.size(); ++i) {
            cv::Rect rect = squares[i];
            CGSize screenSize = UIScreen.mainScreen.bounds.size;
            CGFloat x = (rect.x) * screenSize.width /width;
            CGFloat y = (rect.y) * screenSize.height /height;
                        
            CGRect oc_Rect = CGRectMake(x, y, rect.width, rect.height);
            
            if (self.detectBlock) {
                self.detectBlock(oc_Rect);
            }
        }
    });
    
    [self.previewView previewBuffer:pixelBuffer];
    
    
}

@end
