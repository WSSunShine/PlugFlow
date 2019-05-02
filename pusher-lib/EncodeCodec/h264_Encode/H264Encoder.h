//  H264HWEncoder.h

#import "QMTV_VideoFrame.h"
@protocol  Sendvideoframedelegate <NSObject>
- (void)sendVideoframe:(QMTV_VideoFrame*)videoframe;
@end

@interface H264Encoder : NSObject

@property (nonatomic, weak) id<Sendvideoframedelegate> delegate;

//动态调整参数
@property (nonatomic, assign) int Width;
@property (nonatomic, assign) int Height;
@property (nonatomic, assign) int FPS;
@property (nonatomic, assign) int Bitrate;

- (id) init :(int)width Height:(int)height FPS:(int)fps Bitrate:(int)bitrate;


- (void) encode:(CVImageBufferRef) cpixcel timeStamp:(uint64_t)timeStamp;

-(void)invalidate;

@end
