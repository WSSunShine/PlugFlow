//  QMTV_Frame

#import <Foundation/Foundation.h>

@interface QMTV_Frame : NSObject

//timestamp
@property (nonatomic, assign) uint64_t timestamp;
//yuv data
@property (nonatomic, strong) NSData *data;
//h264 headdata
@property (nonatomic, strong) NSData *header;

@end
