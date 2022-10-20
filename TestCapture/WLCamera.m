//
//  WLCamera.m
//  TestCapture
//
//  Created by zz on 2022/10/20.
//

#import "WLCamera.h"
#import <AVFoundation/AVFoundation.h>

@interface WLCamera()
<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureDevicePosition *_devicePosition;
}
@property (nonatomic ,strong) AVCaptureSession *captureSession;
@property (nonatomic ,strong) AVCaptureDevice  *device;

@property (nonatomic , strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic , strong) AVCaptureVideoDataOutput *deviceOutput;

@property (nonatomic , strong) AVCaptureConnection *captureConnection;

@property (nonatomic , strong) dispatch_queue_t bufferQueue;
@end

@implementation WLCamera
- (instancetype)init {
    if (self = [super init]) {
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
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        [self.captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
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
    self.deviceOutput.alwaysDiscardsLateVideoFrames = YES;
    // 输出视频色彩空间为yuv420（也可以为RGB）
    self.deviceOutput.videoSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
    };
    // 设置视频数据输出回调
    [self.deviceOutput setSampleBufferDelegate:self queue:self.bufferQueue];
    self.captureConnection = [self.deviceOutput connectionWithMediaType:AVMediaTypeVideo];
    
    // 设置输出图像方向
    if ([self.captureConnection isVideoOrientationSupported]) {
        [self.captureConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    // 设置是否镜像
    if ([self.captureConnection isVideoMirroringSupported]) {
        [self.captureConnection setVideoMirrored:YES];
    }
    
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddOutput:self.deviceOutput]) {
        [self.captureSession addOutput:self.deviceOutput];
    }
    [self.captureSession commitConfiguration];
}


#pragma mark -- public func
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
        
        AVCaptureDeviceDiscoverySession *sessionDiscovery = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        
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
    NSLog(@"%@",pixelBuffer);
}

@end
