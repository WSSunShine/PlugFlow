//VideoCapture.m

#import <UIKit/UIKit.h>
#import "GPUImage.h"


#import "VideoAndAudioCapture.h"

#import "QMTV_GPUImageBeautyFilter.h"
#import "QMTV_GPUImageEmptyFilter.h"

@interface VideoAndAudioCapture()<GPUImageVideoCameraDelegate>

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageView *gpuImageView;

//@property (nonatomic, strong) GPUImageCropFilter *cropfilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *emptyFilter;

@property (nonatomic, assign) BOOL is_horizontal;
@property (nonatomic, assign) BOOL isPreviewing;
@property (nonatomic, assign) BOOL isEncoding;
@property (nonatomic, assign) BOOL is_beaufiful;
@property (nonatomic, assign) int CurrentFPS;
@property (nonatomic, assign) NSString *size;
@end

@implementation VideoAndAudioCapture

#pragma mark -- 初始化
- (nullable instancetype)initVideoW :(int)width
                          initVideoH:(int)height
                             initFPS:(int)FPS
                          horizontal:(BOOL)is_horizontal{
    if(self = [super init]){
        
        switch (width) {
            case 360:
                _size=[NSString stringWithString:AVCaptureSessionPreset1280x720];
                break;
            case 540:
                _size=[NSString stringWithString:AVCaptureSessionPresetiFrame960x540];
                break;
            case 720:
                _size=[NSString stringWithString:AVCaptureSessionPreset1280x720];
                break;
            case 640:
                _size=[NSString stringWithString:AVCaptureSessionPreset640x480];
                break;
            case 960:
                _size=[NSString stringWithString:AVCaptureSessionPresetiFrame960x540];
                break;
            case 1280:
                _size=[NSString stringWithString:AVCaptureSessionPreset1280x720];
                break;
            default:
                _size=[NSString stringWithString:AVCaptureSessionPreset1280x720];
                break;
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        _CurrentFPS=FPS;
        self.is_horizontal=is_horizontal;
        [self BeautyFace:YES];
        self.isPreviewing = NO;
        self.mirror = YES;
    }
    return self;
}
#pragma mark -- 改变方向重置设定
- (void)setSessionFrameWidth:(int)Width
                      Height:(int)Height
                         FPS:(int)FPS
                  Horizontal:(BOOL)Is_horizontal{

    switch (Width) {
        case 360:
            _size=[NSString stringWithString:AVCaptureSessionPreset1280x720];
            break;
        case 540:
            _size=[NSString stringWithString:AVCaptureSessionPresetiFrame960x540];
            break;
        case 720:
            _size=[NSString stringWithString:AVCaptureSessionPreset1280x720];
            break;
        case 640:
            _size=[NSString stringWithString:AVCaptureSessionPreset640x480];
            break;
        case 960:
            _size=[NSString stringWithString:AVCaptureSessionPresetiFrame960x540];
            break;
        case 1280:
            _size=[NSString stringWithString:AVCaptureSessionPreset1280x720];
            break;
        default:
            _size=[NSString stringWithString:AVCaptureSessionPreset1280x720];
            break;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    _CurrentFPS=FPS;
    self.is_horizontal=Is_horizontal;
    [self BeautyFace:YES];
    self.isPreviewing = NO;
    self.mirror = YES;
}
#pragma mark -- 懒加载
-(GPUImageVideoCamera*)videoCamera{
    if(!_videoCamera){
        _videoCamera = [[GPUImageVideoCamera alloc]
                        initWithSessionPreset:_size
                        cameraPosition:AVCaptureDevicePositionBack];
        
        if([_videoCamera addAudioInputsAndOutputs]){
            _videoCamera.delegate=self;
        }
        _videoCamera.frameRate=_CurrentFPS;
        
        _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
        
        _videoCamera.horizontallyMirrorRearFacingCamera = NO;
    
    }
    if(_is_horizontal){
        _videoCamera.outputImageOrientation = UIDeviceOrientationLandscapeLeft;
    }
    else{
        _videoCamera.outputImageOrientation = UIDeviceOrientationPortrait;
    }
    
    _videoCamera.captureSessionPreset=_size;
    
    return _videoCamera;
}
-(GPUImageView*)gpuImageView{
    if(!_gpuImageView){
        _gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [_gpuImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    }
    return _gpuImageView;

}
#pragma mark -- 设置fps
- (void)setVideoFrameRate:(NSInteger)videoFrameRate{
    if(videoFrameRate <= 0) return;
    if(videoFrameRate == self.videoCamera.frameRate) return;
    self.videoCamera.frameRate = (uint32_t)videoFrameRate;
}

- (NSInteger)videoFrameRate{
    return self.videoCamera.frameRate;
}

#pragma mark -- 预览
- (void)startPreview {
    if (!_isPreviewing) {
        _isPreviewing = YES;
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self.videoCamera startCameraCapture];
    }
    
}
- (void)stopPreview {
    if (_isPreviewing) {
        _isPreviewing = NO;
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self.videoCamera stopCameraCapture];
    }
}

- (void)setPreView:(UIView *)preView{
    if(self.gpuImageView.superview) [self.gpuImageView removeFromSuperview];
    [preView insertSubview:self.gpuImageView atIndex:0];
}

- (UIView*)preView{
    return self.gpuImageView.superview;
}

#pragma mark -- 编码
- (void)startEncoding {
    if (!_isEncoding) {
        _isEncoding = YES;
        NSLog(@"\nCamera: StartRunning");
    }
}
- (void)stopEncoding {
    if (_isEncoding) {
        _isEncoding = NO;
        NSLog(@"\nCamera: StopRunning");
    }
}
#pragma mark -- 镜像
- (void)setMirror:(BOOL)mirror {
    _mirror = mirror;
}

- (void)reloadMirror{
    
    if(self.mirror && self.videoCamera.cameraPosition == AVCaptureDevicePositionFront){
        self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
        [self.gpuImageView setInputRotation:kGPUImageFlipHorizonal atIndex:0];
    }else if (! self.mirror && self.videoCamera.cameraPosition == AVCaptureDevicePositionFront){
        self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
        [self.gpuImageView setInputRotation:kGPUImageNoRotation atIndex:0];
    }
    else{
        [self.gpuImageView setInputRotation:kGPUImageNoRotation atIndex:0];
    }
}
#pragma mark -- 转镜头
- (void)rotateCamera:(AVCaptureDevicePosition) posion{
    
    [_videoCamera rotateCameraWithPosition:posion];
    
    _videoCamera.frameRate=_CurrentFPS;
    
    [self reloadMirror];
    
}
#pragma mark -- 滤镜设置
- (void)BeautyFace:(BOOL)beautyFace{

    [_emptyFilter removeAllTargets];
    [_filter removeAllTargets];
    [self.videoCamera removeAllTargets];
    
    if(beautyFace){
        _filter = [[QMTV_GPUImageBeautyFilter alloc] init];
        _emptyFilter = [[QMTV_GPUImageEmptyFilter alloc] init];
    }else{
        _filter = [[QMTV_GPUImageEmptyFilter alloc] init];
    }
     [self reloadMirror];
    __weak typeof(self) _self = self;
    [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        [_self processVideo:output];
    }];
    
    [_videoCamera addTarget:_filter];

    if (beautyFace) {
        [_filter addTarget:_emptyFilter];
        if(self.gpuImageView) [_emptyFilter addTarget:self.gpuImageView];
    } else {
        if(self.gpuImageView) [_filter addTarget:self.gpuImageView];
    }
    
}

#pragma mark -- 闪光灯
-(void)TurnFlashOn_platform:(BOOL)isTurn{
    NSError *err = nil;
    BOOL lockAcquired = [self.videoCamera.inputCamera lockForConfiguration:&err];
    
    if (lockAcquired) {
        AVCaptureTorchMode nextTorchMode;
        if(isTurn){
            nextTorchMode= AVCaptureTorchModeOn;
        }
        else{
            nextTorchMode= AVCaptureTorchModeOff;
        }
        
        if (self.videoCamera.inputCamera.hasTorch && [self.videoCamera.inputCamera isTorchModeSupported:nextTorchMode]) {
            self.videoCamera.inputCamera.torchMode = nextTorchMode;
        }
        [self.videoCamera.inputCamera unlockForConfiguration];
    } else {
        NSLog(@"CANNOT SET CAMERA TORCH, DEVICE ERROR! error=%@", err);
    }
    
}
#pragma mark -- 影像buffer
- (void) processVideo:(GPUImageOutput *)output{
    if (!_isEncoding) {
        return;
    }
    __weak typeof(self) _self = self;
    @autoreleasepool {
        GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
        CVPixelBufferRef pixelBuffer = [imageFramebuffer pixelBuffer];
        if(_self.videodelegate && [_self.videodelegate respondsToSelector:@selector(EncodeVideoFrame:)]){
            [_self.videodelegate EncodeVideoFrame:pixelBuffer];
        }
    }
}
#pragma mark -- 声音buffer
-(void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    
    if (!_isEncoding) {
        return;
    }
    if(self.audiodelegate && [self.audiodelegate respondsToSelector:@selector(EncodeAudioFrame:)]){
        [self.audiodelegate EncodeAudioFrame:sampleBuffer];
    }
}

#pragma mark - 美颜效果
- (void)setBeautyWithToneLevel:(CGFloat)toneLevel beautyLevel:(CGFloat)beautyLevel brightLevel :(CGFloat)brightLevel{
    [(QMTV_GPUImageBeautyFilter *)_filter setBeautyWithToneLevel:toneLevel beautyLevel:beautyLevel brightLevel:brightLevel];
}

#pragma mark Notification
- (void)willEnterBackground:(NSNotification*)notification{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.videoCamera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}

- (void)willEnterForeground:(NSNotification*)notification{
    [self.videoCamera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)dealloc{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
