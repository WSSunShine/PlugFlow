
//  FrameSession.m

#import "FrameSession.h"
#import "VideoAndAudioCapture.h"

#import "H264Encoder.h"
#import "AACEncoder.h"

#import "QMTV_StreamRtmpSocket.h"
#import "QMTV_Stream.h"




/*时间戳*/
#define NOW (CACurrentMediaTime()*1000)

@interface FrameSession()<videoEncodeDelgate,audioEncodeDelgate,Sendvideoframedelegate,SendAudioframedelegate,QMTV_StreamSocketDelegate>{
    
    int currentnetworkstate;
    int currentstate;
    int currenterror;
}

/*防止rtmp停止后 还有frame 继续传送 形成一个死循环 造成cpu与 memory 累积 在停止后加上一个开关*/
@property (nonatomic,assign) BOOL upload;

/*时间戳*/
@property (nonatomic, assign) uint64_t timestamp;

//目前时间戳
@property (nonatomic, assign) uint64_t currentTimestamp;

//RTMP
@property (nonatomic,strong) QMTV_StreamRtmpSocket *rtmpsocket;

//h264编码器
@property (nonatomic,strong) H264Encoder *h264;

//aac编码器
@property (nonatomic,strong) AACEncoder *aac;

//影像采集
@property (nonatomic,strong) VideoAndAudioCapture *videoAndaudioCapture;

//建立stream
@property (nonatomic,strong) QMTV_Stream* stream;

/// 时间戳锁
@property (nonatomic, strong) dispatch_semaphore_t lock;

/// 上传相对时间戳
@property (nonatomic, assign) uint64_t relativeTimestamps;


//動態調整
@property (nonatomic,assign) int FPS;

@property (nonatomic,assign) int Width;

@property (nonatomic,assign) int Height;

@property (nonatomic,assign) int Bitrate;

@property (nonatomic,assign) BOOL horizontal;

@end


@implementation FrameSession

@synthesize flashlightON=_flashlightON;
@synthesize capturePositionBack=_capturePositionBack;
@synthesize beautyFace=_beautyFace;
@synthesize muted=_muted;

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        
    }
    return self;
}

static FrameSession* shareInstace = nil;

+ (instancetype)getInstance
{
    static dispatch_once_t instance;
    dispatch_once(&instance, ^{
        shareInstace = [[self alloc] init];
    });
    return shareInstace;
}
#pragma mark --更改参数设定
- (void)setSessionFrameWidth:(int)width
                      height:(int)height
                         FPS:(int)FPS
                     bitrate:(int)bitrate
                  horizontal:(BOOL)is_horizontal{
    
    [self.videoCapture setSessionFrameWidth:width Height:height FPS:FPS Horizontal:is_horizontal];
    
    self.Width=width;
    self.Height=height;
    self.FPS=FPS;
    self.Bitrate=bitrate;
    [self setupH264];
    self.capturePositionBack=AVCaptureDevicePositionFront;
    self.flashlightON=false;
}

-(void)setupH264{
    
    //每次重新设定方向前，先销毁在建立
    if(self.h264){
        [self.h264 invalidate];
    }
    
    self.h264=[[H264Encoder alloc] init:self.Width
                                 Height:self.Height
                                    FPS:self.FPS
                                Bitrate:self.Bitrate];
    
    [self.h264 setDelegate:self];
}


#pragma mark -- h264-delegate
-(void)EncodeVideoFrame : (CVImageBufferRef) cpixcel {
    [self.h264 encode:cpixcel timeStamp:NOW];
}
#pragma mark -- aac-delegate
-(void)EncodeAudioFrame : (CMSampleBufferRef)samplebuffer{
    [self.aac encodeAudioData:samplebuffer timeStamp:NOW];
}

#pragma mark -- rtmp-delegate
- (void)sendVideoframe:(QMTV_VideoFrame*)videoframe{
    
    if(self.relativeTimestamps == 0){
        self.relativeTimestamps = videoframe.timestamp;
    }
    videoframe.timestamp = [self uploadTimestamp:videoframe.timestamp];
    if(self.upload){
        [self.rtmpsocket sendFrame:videoframe];
    }
}

-(void)sendAudioframe:(QMTV_AudioFrame *)audioframe{
    
    if(self.relativeTimestamps == 0){
        self.relativeTimestamps = audioframe.timestamp;
    }
    audioframe.timestamp = [self uploadTimestamp:audioframe.timestamp];
    
    if(self.upload){
        [self.rtmpsocket sendFrame:audioframe];
    }
}



#pragma mark --预览画面
-(void)Preview:(UIView*)view{
    [self.videoCapture setPreView:view];
}

-(void)startPreview{
    [self.videoCapture startPreview];
}

-(void)stopPreview{
    [self.videoCapture stopPreview];
}

#pragma mark --编码
-(void)startEncoding{
    
    [self.rtmpsocket start];
    
    self.upload=true;
    
    [self.videoCapture startEncoding];
    
}

-(void)stopEncoding{
    
    [self.videoCapture stopEncoding];
    
    self.upload=false;
    
    [self.rtmpsocket stop];
    
    self.relativeTimestamps = 0;
    
}

-(void)Rtmp_url:(NSString*)url{
    self.stream.url=url;
}

#pragma mark -- 获取camera权限
- (void)requestAccessForVideo{
    
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:{
            //對話窗沒有出現，發起授權
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self startPreview];
                    });
                }
            }];
            break;
        }
        case AVAuthorizationStatusAuthorized:{
            //開啟授權
            [self startPreview];
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            //用戶拒絕開啟授權或是相機關閉
            
            break;
        default:
            break;
    }
}
#pragma mark -- 获取mic权限
- (void)requestAccessForAudio{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:{
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                
            }];
            break;
        }
        case AVAuthorizationStatusAuthorized:{
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            break;
        default:
            break;
    }
}

#pragma mark --懒加载
-(VideoAndAudioCapture*)videoCapture{
    if(!_videoAndaudioCapture){
        _videoAndaudioCapture=[[VideoAndAudioCapture alloc]initVideoW:self.Width
                                           initVideoH:self.Height
                                              initFPS:self.FPS
                                           horizontal:self.horizontal];
        
        [_videoAndaudioCapture setVideodelegate:self];
        [_videoAndaudioCapture setAudiodelegate:self];
    }
    return _videoAndaudioCapture;
}

-(AACEncoder*)aac{
    if(!_aac){
        _aac=[[AACEncoder alloc]init];
        [_aac setDelegate:self];
    }
    return _aac;
}

-(QMTV_Stream*)stream{
    if(!_stream){
        _stream=[[QMTV_Stream alloc]init];
    }
    _stream.bitrate=self.Bitrate;
    _stream.width=self.Width;
    _stream.height=self.Height;
    _stream.fps=self.FPS;
    return _stream;
}

-(QMTV_StreamRtmpSocket*)rtmpsocket{
    if(!_rtmpsocket){
        _rtmpsocket=[[QMTV_StreamRtmpSocket alloc] initWithStream:self.stream];
    }
    return _rtmpsocket;
    
}

#pragma mark --闪光灯
-(void)setFlashlightON:(BOOL)on {
    
    [self.videoCapture TurnFlashOn_platform:on];
    
    _flashlightON=on;
}
-(BOOL)flashlightON{
    return _flashlightON;
}

#pragma mark --镜头方向
-(void)setCapturePositionBack:(AVCaptureDevicePosition)posion{

    [self.videoCapture rotateCamera:posion];
    
    _capturePositionBack=posion;
    
}

-(AVCaptureDevicePosition)capturePositionBack{
    
    return _capturePositionBack;
}

#pragma mark -- 设置镜像
- (void)setMirror:(BOOL)mirror {
    
    [self.videoAndaudioCapture setMirror:mirror];
    [self.videoAndaudioCapture reloadMirror];
    
}
#pragma mark --美颜开关
- (void)setBeautyFace:(BOOL)beautyFace{
    [self.videoCapture BeautyFace:beautyFace];
    _beautyFace=beautyFace;
}
-(BOOL)beautyFace{
    
    return _beautyFace;
}

#pragma mark --上传时间戳
- (uint64_t)uploadTimestamp:(uint64_t)captureTimestamp{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    currentts = captureTimestamp - self.relativeTimestamps;
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

- (dispatch_semaphore_t)lock{
    if(!_lock){
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

#pragma mark -- NetWork delegate
- (void)socketBufferStatus:(nullable id<QMTV_StreamSocket>)socket status:(QMTV_StreamingState)status{
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(GetCurrentBufferState:)]){
        switch (status) {
            case QMTV_StreamingUnknown:
                [self.delegate GetCurrentBufferState:BufferUnknow];
                break;
            case QMTV_StreamingIncrease:
                [self.delegate GetCurrentBufferState:BufferGood];
                break;
            case QMTV_StreamingDecline:
                [self.delegate GetCurrentBufferState:BufferBad];
                break;
            default:
                break;
        }
    }
}

- (void)socketStatus:(nullable id<QMTV_StreamSocket>)socket status:(QMTV_StreamState)status{
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(GetCurrentConnectState:)]){
        switch (status) {
            case QMTV_StreamStateStreamStateUnknow:
                [self.delegate GetCurrentConnectState:StateUnknow];
                break;
            case QMTV_StreamStateConnecting:
                [self.delegate GetCurrentConnectState:StateConnecting];
                break;
            case QMTV_StreamStateConnected:
                [self.delegate GetCurrentConnectState:StateConnected];
                break;
            case QMTV_StreamStateRconnecting:
                [self.delegate GetCurrentConnectState:StreamStateRconnecting];
                break;
            case QMTV_StreamStateDisconnected:
                [self.delegate GetCurrentConnectState:StreamStateDisconnected];
                break;
            case QMTV_StreamStateError:
                [self.delegate GetCurrentConnectState:StreamStateError];
                break;
            default:
                break;
        }
    }
}

- (void)socketDidError:(nullable id<QMTV_StreamSocket>)socket errorCode:(QMTV_StreamSocketErrorCode)errorCode{
    if(self.delegate && [self.delegate respondsToSelector:@selector(GetCurrentConnectError:)]){
        switch (errorCode) {
            case QMTV_StreamSocketError_ConnectSocket:
                [self.delegate GetCurrentConnectError:StateError_ConnectSocket];
                break;
            case QMTV_StreamSocketError_Verification:
                [self.delegate GetCurrentConnectError:StateError_Verification];
                break;
            case QMTV_StreamSocketError_ReConnectTimeOut:
                [self.delegate GetCurrentConnectError:StateError_ReConnectTimeOut];
                break;
            default:
                break;
        }
    }
}

//调整美颜效果
- (void)setBeautyWithToneLevel:(CGFloat)toneLevel beautyLevel:(CGFloat)beautyLevel brightLevel :(CGFloat)brightLevel{
    [self.videoAndaudioCapture setBeautyWithToneLevel:toneLevel beautyLevel:beautyLevel brightLevel:brightLevel];
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
