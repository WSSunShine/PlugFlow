//  VideoAndAudioCapture.h

#import "FrameSession.h"
#import "GPUImage.h"

@protocol  videoEncodeDelgate <NSObject>
- (void)EncodeVideoFrame : ( nonnull CVImageBufferRef) cpixcel;
@end

@protocol  audioEncodeDelgate <NSObject>
-(void)EncodeAudioFrame : ( nonnull CMSampleBufferRef) samplebuffer;
@end


@interface VideoAndAudioCapture : NSObject

@property(nonatomic, weak,nullable) id< videoEncodeDelgate> videodelegate;

@property(nonatomic, weak,nullable) id< audioEncodeDelgate> audiodelegate;


//預覽
@property (null_resettable,nonatomic, strong) UIView * preView;

//转向镜头
- (void)rotateCamera:(AVCaptureDevicePosition) posion;

//是否打開美顏
- (void)BeautyFace:(BOOL)beautyFace;


//初始化 horizontal_Orientation:是否要橫向
- (nullable instancetype)initVideoW :(int)width
                          initVideoH:(int)height
                             initFPS:(int)FPS
                          horizontal:(BOOL)is_horizontal;

//重设定Session
- (void)setSessionFrameWidth:(int)Width
                      Height:(int)Height
                         FPS:(int)FPS
                  Horizontal:(BOOL)Is_horizontal;

//開始預覽 獲取buffer
- (void)startPreview;

//停止預覽 停止buffer
- (void)stopPreview;

//開始編碼h264
- (void)startEncoding ;

//停止編碼
- (void)stopEncoding;

//打开闪光灯
-(void)TurnFlashOn_platform:(BOOL)isTurn;

//是否打開鏡像
@property (nonatomic, assign) BOOL mirror;

- (void)reloadMirror;

//调整美颜效果
- (void)setBeautyWithToneLevel:(CGFloat)toneLevel beautyLevel:(CGFloat)beautyLevel brightLevel :(CGFloat)brightLevel;

@end
