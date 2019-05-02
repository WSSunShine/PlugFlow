//  FrameSession.h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


//橫向480p
#define LIVE_VIEDO_SIZE_HORIZONTAL_480P  (CGSizeMake(640, 480))
//橫向540p
#define LIVE_VIEDO_SIZE_HORIZONTAL_540P  (CGSizeMake(960, 540))

//竖屏360p
#define LIVE_VIEDO_SIZE_360P  (CGSizeMake(360, 640))
//竖屏540p
#define LIVE_VIEDO_SIZE_540P   (CGSizeMake(540, 960))
//竖屏720p
#define LIVE_VIEDO_SIZE_720P (CGSizeMake(720, 1280))

//FPS
typedef NS_ENUM(NSUInteger, LIVE_FRAMERATE) {
    LIVE_FRAMERATE_30=30,
    LIVE_FRAMERATE_25=25,
    LIVE_FRAMERATE_20=20,
    LIVE_FRAMERATE_15=15
};

//Bitrate
typedef NS_ENUM(NSUInteger, LIVE_BITRATE) {
    LIVE_BITRATE_1Mbps=1500000,
    LIVE_BITRATE_800Kbps=800000,
    LIVE_BITRATE_500Kbps=500000
};


//buffer状况
typedef NS_ENUM(NSUInteger, BufferState) {
    BufferUnknow = 0,
    BufferGood=1,//状况良好
    BufferBad=2 //状况极差
};

//rtmp 连结状态
typedef NS_ENUM(NSUInteger, ConnectState) {
    StateUnknow=0,
    StateConnecting=1,
    StateConnected=2,
    StreamStateRconnecting=3,
    StreamStateDisconnected=4,
    StreamStateError=5
};

//rtmp 连结失败
typedef NS_ENUM(NSUInteger, ConnectError) {
    StateError_ConnectSocket=0,//连接socket失败
    StateError_Verification=1,//验证服务器失败
    StateError_ReConnectTimeOut=2//重新连接服务器超时
};

@protocol FrameSessionDelgate <NSObject>

@optional
-(void)GetCurrentBufferState:(BufferState)state;

-(void)GetCurrentConnectState:(ConnectState)state;

-(void)GetCurrentConnectError:(ConnectError)state;

@end


@interface FrameSession : NSObject

+(nonnull instancetype)getInstance;

@property(nullable,nonatomic,weak) id<FrameSessionDelgate> delegate;


//打开camera
-(void)requestAccessForVideo;

//打开mic
- (void)requestAccessForAudio;

//设定rtmp url
-(void)Rtmp_url:(nullable NSString*)url;

/*
 *initVideoW 编码的宽度
 *initVideoH 编码的高度
 *initBitrate 码率
 *initFPS 帧率
 *horizontal 是否橫向
 */
- (nonnull FrameSession*)initVideoW :(int)width
         initVideoH:(int)height
        initBitrate:(int)bitrate
            initFPS:(int)FPS
         horizontal:(BOOL)is_horizontal;


//更换参数
- (void)setSessionFrameWidth:(int)width
                      height:(int)height
                         FPS:(int)FPS
                     bitrate:(int)bitrate
                  horizontal:(BOOL)is_horizontal;
//设定预览画面
-(void)Preview:(nullable UIView*)view;

//开始预览
-(void)startPreview;

//停止预览
-(void)stopPreview;

//开始编码
-(void)startEncoding;

//结束编码
-(void)stopEncoding;

//美颜开关
@property (nonatomic, assign) BOOL beautyFace;

//是否打開鏡像
@property (nonatomic, assign) BOOL mirror;

//靜音
@property (nonatomic,assign) BOOL muted;

//打开闪光灯
@property (nonatomic, assign) BOOL flashlightON;

//控制镜头方向
@property (nonatomic, assign) AVCaptureDevicePosition capturePositionBack;

//调整美颜效果
- (void)setBeautyWithToneLevel:(CGFloat)toneLevel beautyLevel:(CGFloat)beautyLevel brightLevel :(CGFloat)brightLevel;

@end
