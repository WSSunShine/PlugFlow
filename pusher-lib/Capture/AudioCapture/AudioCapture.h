//  AudioCapture.h

#import "FrameSession.h"

@protocol  audioEncodeDelgate <NSObject>
-(void)EncodeAudioFrame : (AudioBufferList)inBufferList;
@end

@interface AudioCapture : NSObject

@property(nonatomic, weak,nullable) id<audioEncodeDelgate> delegate;

//静音开关
@property (nonatomic,assign) BOOL muted;

//是否录音
@property (nonatomic, assign) BOOL running;

//初始化
- (nullable instancetype)initWithAudio;

//銷毀
-(void)invalidate;

@end
