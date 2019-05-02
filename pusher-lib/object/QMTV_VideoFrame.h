//  QMTV_Frame.h

#import "QMTV_Frame.h"

@interface QMTV_VideoFrame : QMTV_Frame

@property (nonatomic, assign) BOOL isKeyFrame;

@property (nonatomic, strong) NSData *sps;

@property (nonatomic, strong) NSData *pps;

@end
