// QMTVStreamingBuffer.h

#import <Foundation/Foundation.h>
#import "QMTV_AudioFrame.h"
#import "QMTV_VideoFrame.h"

typedef NS_ENUM(NSUInteger, QMTV_StreamingState) {
    QMTV_StreamingUnknown = 0,
    QMTV_StreamingIncrease = 1,    //< 缓冲区状态好可以增加码率
    QMTV_StreamingDecline = 2      //< 缓冲区状态差应该降低码率
};
@class QMTV_StreamingBuffer;

@protocol QMTV_StreamingBufferDelegate <NSObject>
- (void)streamingBuffer:(nullable QMTV_StreamingBuffer * )buffer bufferState:(QMTV_StreamingState)state;
@end

@interface QMTV_StreamingBuffer : NSObject

@property (nullable,nonatomic, weak) id <QMTV_StreamingBufferDelegate> delegate;

//目前队列
@property (nonatomic, strong, readonly) NSMutableArray <QMTV_Frame*>* _Nonnull list;

//队列最大数量
@property (nonatomic, assign) NSUInteger maxCount;

//是否需要丟帧
@property (nonatomic, assign) BOOL needDropFrame;

//最後丟帧数
@property (nonatomic, assign) NSInteger lastDropFrames;

//新增到队列
- (void)appendObject:(nullable QMTV_Frame*)frame;

//送出第一帧
- (nullable QMTV_Frame*)popFirstObject;

//删除队列
- (void)removeAllObject;

@end
