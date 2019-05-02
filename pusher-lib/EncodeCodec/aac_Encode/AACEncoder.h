//  AACEncoder.h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "QMTV_AudioFrame.h"



@protocol  SendAudioframedelegate <NSObject>
- (void)sendAudioframe:(QMTV_AudioFrame*)audio_frame;
@end

@interface AACEncoder : NSObject
- (void)encodeAudioData:(CMSampleBufferRef)samplebuffer timeStamp:(uint64_t)timeStamp;
@property (nonatomic, weak) id<SendAudioframedelegate> delegate;

@end